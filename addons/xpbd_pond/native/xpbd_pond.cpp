#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/convex_polygon_shape2d.hpp>
#include <godot_cpp/classes/geometry2d.hpp>
#include <godot_cpp/classes/rigid_body2d.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/transform2d.hpp>
#include <algorithm>
#include <cmath>
#include <limits>
#include <vector>
using namespace godot;

// Faithful hot-loop port of soft_pond_layer.gd. Scalars remain doubles,
// Vector2 and packed lambda/gradient storage retain Godot's float precision.
// No new force, constraint, damping, collision rule or solver ordering.
class XPBDPondKernel : public RefCounted {
    GDCLASS(XPBDPondKernel, RefCounted);
    static constexpr int N = 6;
    struct PairState {
        Dictionary a, b;
        Vector2i key;
        double wa=0, wb=0, denominator=0, allowed=0, margin=0;
        Vector2 normal;
        PackedFloat32Array ga, gb;
        bool has_contact=false, recorded=false;
    };
    static Vector2 center(const PackedVector2Array &p) {
        Vector2 c;
        for (int i=0;i<p.size();++i) c += p[i] / real_t(p.size());
        return c;
    }
    static double area(const PackedVector2Array &p) {
        double a=0;
        for (int i=0;i<p.size();++i) a += double(p[i].cross(p[(i+1)%p.size()])) * 0.5;
        return a;
    }
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("structure","state","dt","weight","compression","area_compliance"), &XPBDPondKernel::structure);
        ClassDB::bind_method(D_METHOD("surface","state"), &XPBDPondKernel::surface);
        ClassDB::bind_method(D_METHOD("support","points","axis"), &XPBDPondKernel::support);
        ClassDB::bind_method(D_METHOD("surface_gradient","state","indices"), &XPBDPondKernel::surface_gradient);
        ClassDB::bind_method(D_METHOD("weighted","points","weights"), &XPBDPondKernel::weighted);
        ClassDB::bind_method(D_METHOD("correct_surface","state","weights","correction","stabilization"), &XPBDPondKernel::correct_surface);
        ClassDB::bind_method(D_METHOD("resolve_contact","a","b","manifold","wa","wb"), &XPBDPondKernel::resolve_contact);
        ClassDB::bind_method(D_METHOD("solve_constraints","active","pairs","dt","iterations","compression","area_compliance","planes","manifolds","contacts","owner"), &XPBDPondKernel::solve_constraints);
    }
public:
    static RigidBody2D *body(Dictionary s) { return Object::cast_to<RigidBody2D>(s["ball"]); }
    static double inverse_mass(Dictionary s) { return double(N)/double(body(s)->get_mass()); }
    static void record_contact(Dictionary contacts, Dictionary a, Dictionary b, Vector2 normal) {
        Array pair; pair.push_back(a["ball"]); pair.push_back(b["ball"]); pair.push_back(normal);
        contacts[String::num_uint64(body(a)->get_instance_id())+":"+String::num_uint64(body(b)->get_instance_id())]=pair;
    }
    Ref<ConvexPolygonShape2D> query_shape(Dictionary s) {
        Ref<ConvexPolygonShape2D> shape=s["query_shape"];
        if (bool(s["query_dirty"])) {
            PackedVector2Array hull=Geometry2D::get_singleton()->convex_hull(s["contact_surface"]);
            if (hull.size()>1) hull.remove_at(hull.size()-1);
            shape->set_points(hull);
            s["query_dirty"]=false;
        }
        return shape;
    }
    void walls(Dictionary s, const Array &planes, Object *owner) {
        Array wall_manifolds=s["wall_manifolds"];
        if (wall_manifolds.is_empty()) {
            const bool full_patch=s.has("wall_sectors");
            const PackedVector2Array outline=full_patch ? mapped_surface(s,s["wall_sectors"]) : surface(s);
            const Array bindings=full_patch ? Array(s["wall_outline_bindings"]) : Array(s["outline_bindings"]);
            for (int k=0;k<planes.size();++k) {
                Dictionary plane=planes[k], m;
                Vector2 normal=plane["normal"];
                PackedFloat32Array gradient=gradient_from_bindings(bindings,support(outline,-normal));
                double denominator=0;
                for (int i=0;i<N;++i) denominator+=double(gradient[i])*double(gradient[i]);
                m["normal"]=normal; m["gradient"]=gradient; m["plane"]=plane["plane"];
                m["inverse_mass"]=1.0/std::max(denominator,0.000001); m["body"]=plane["body"];
                wall_manifolds.push_back(m);
            }
        }
        Dictionary boundary=s["boundary"];
        for (int k=0;k<wall_manifolds.size();++k) {
            Dictionary m=wall_manifolds[k];
            Vector2 normal=m["normal"];
            PackedFloat32Array gradient=m["gradient"];
            double depth=double(m["plane"])-double(weighted(s["points"],gradient).dot(normal));
            if (depth<=0) continue;
            if (bool(body(s)->get_meta("directional_flight",false)) && std::abs(normal.x)>0.5)
                s["flight_side_normal"]=normal;
            correct_surface(s,gradient,normal*real_t(depth)*real_t(double(m["inverse_mass"])),0);
            for (int i=0;i<N;++i) if (std::abs(gradient[i])>0.02) boundary[i]=normal;
            // Keep gameplay notification timing within the plane loop.
            owner->call("_notify",s["ball"],m["body"]);
        }
    }
    void collide(PairState &pair, Dictionary manifolds, Dictionary contacts) {
        const Dictionary &a=pair.a, &b=pair.b;
        if (pair.has_contact) {
            resolve_pair(pair,contacts);
            return;
        }
        // Stored envelope excludes distant pairs before any dense outline work.
        const double reach=double(a["broad_radius"])+double(b["broad_radius"]);
        if (center(a["points"]).distance_squared_to(center(b["points"]))>reach*reach) return;
        PackedVector2Array sa=surface(a), sb=surface(b);
        Rect2 bounds_a=a["surface_bounds"], bounds_b=b["surface_bounds"];
        if (!bounds_a.grow(0.02).intersects(bounds_b,true)) return;
        Ref<ConvexPolygonShape2D> qa=query_shape(a), qb=query_shape(b);
        PackedVector2Array hits=qa->collide_and_get_contacts(Transform2D(),qb,Transform2D());
        if (hits.is_empty()) return;
        double depth=0;
        Vector2 normal;
        for (int i=0;i+1<hits.size();i+=2) {
            Vector2 separation=hits[i+1]-hits[i];
            double length=separation.length();
            if (length>depth) { depth=length; normal=separation/real_t(length); }
        }
        if (normal==Vector2()) return;
        if ((center(b["points"])-center(a["points"])).dot(normal)<0) normal=-normal;
        const bool full_a=a.has("wall_sectors"), full_b=b.has("wall_sectors");
        const PackedVector2Array support_a=full_a ? mapped_surface(a,a["wall_sectors"]) : sa;
        const PackedVector2Array support_b=full_b ? mapped_surface(b,b["wall_sectors"]) : sb;
        PackedFloat32Array ga=gradient_from_bindings(full_a ? Array(a["wall_outline_bindings"]) : Array(a["outline_bindings"]),support(support_a,normal));
        PackedFloat32Array gb=gradient_from_bindings(full_b ? Array(b["wall_outline_bindings"]) : Array(b["outline_bindings"]),support(support_b,-normal));
        Vector2 offset=weighted(b["points"],gb)-weighted(a["points"],ga);
        Dictionary m;
        m["a"]=a; m["b"]=b; m["normal"]=normal; m["ga"]=ga; m["gb"]=gb;
        m["margin"]=double(offset.dot(normal))+depth;
        manifolds[pair.key]=m;
        cache_contact(pair,m);
        resolve_pair(pair,contacts);
    }
    void cache_contact(PairState &pair, const Dictionary &m) {
        pair.normal=m["normal"]; pair.ga=m["ga"]; pair.gb=m["gb"]; pair.margin=m["margin"];
        pair.denominator=0;
        for (int i=0;i<N;++i)
            pair.denominator+=pair.wa*double(pair.ga[i])*pair.ga[i]+pair.wb*double(pair.gb[i])*pair.gb[i];
        const Vector2 va=weighted(pair.a["velocities"],pair.ga), vb=weighted(pair.b["velocities"],pair.gb);
        pair.allowed=std::max(1.0,std::max(0.0,-double((vb-va).dot(pair.normal)))*double(pair.a["step_dt"]));
        pair.has_contact=true;
    }
    void resolve_pair(PairState &pair, Dictionary contacts) {
        const double depth=pair.margin-double((weighted(pair.b["points"],pair.gb)-weighted(pair.a["points"],pair.ga)).dot(pair.normal));
        if (depth < -0.02) return;
        const double dl=std::max(depth,0.0)/std::max(pair.denominator,0.000001);
        const double stabilization=std::clamp((depth-pair.allowed)/std::max(depth,0.000001),0.0,1.0);
        correct_surface(pair.a,pair.ga,-pair.normal*real_t(pair.wa)*real_t(dl),stabilization);
        correct_surface(pair.b,pair.gb,pair.normal*real_t(pair.wb)*real_t(dl),stabilization);
        // Contacts are consumed after this substep, not inside its iterations.
        // Keep first insertion order and the latest substep's normal exactly.
        if (!pair.recorded) {
            record_contact(contacts,pair.a,pair.b,pair.normal);
            pair.recorded=true;
        }
    }
    void solve_constraints(const Array &active, const Array &pairs, double dt, int iterations, double compression,
                           double area_compliance, const Array &planes, Dictionary manifolds, Dictionary contacts, Object *owner) {
        ERR_FAIL_NULL(owner);
        // Convert script pair containers once, outside the eight solver passes.
        std::vector<PairState> native_pairs;
        native_pairs.reserve(pairs.size());
        for (int i=0;i<pairs.size();++i) {
            Array source=pairs[i];
            PairState pair;
            pair.a=source[0]; pair.b=source[1];
            pair.wa=inverse_mass(pair.a); pair.wb=inverse_mass(pair.b);
            pair.key=Vector2i(int32_t(body(pair.a)->get_instance_id()),int32_t(body(pair.b)->get_instance_id()));
            if (manifolds.has(pair.key)) cache_contact(pair,manifolds[pair.key]);
            native_pairs.push_back(pair);
        }
        std::vector<Dictionary> native_states;
        std::vector<double> weights;
        native_states.reserve(active.size()); weights.reserve(active.size());
        for (int i=0;i<active.size();++i) {
            Dictionary state=active[i];
            native_states.push_back(state); weights.push_back(inverse_mass(state));
        }
        for (int iteration=0;iteration<iterations;++iteration) {
            for (int i=0;i<int(native_states.size());++i) {
                structure(native_states[i],dt,weights[i],compression,area_compliance);
            }
            for (Dictionary &state:native_states) walls(state,planes,owner);
            for (PairState &pair:native_pairs) collide(pair,manifolds,contacts);
        }
    }
    void structure(Dictionary s, double dt, double weight, double compression, double area_compliance) {
        PackedVector2Array p=s["points"];
        PackedInt32Array ii=s["edge_i"], jj=s["edge_j"];
        PackedFloat32Array lengths=s["edge_lengths"], compliance=s["edge_compliances"], lambdas=s["edge_lambdas"];
        ERR_FAIL_COND(p.size()!=N || dt<=0 || ii.size()!=jj.size() || ii.size()!=lengths.size() || ii.size()!=compliance.size() || ii.size()!=lambdas.size());
        Vector2 *points=p.ptrw();
        float *lambda=lambdas.ptrw();
        for (int k=0;k<ii.size();++k) {
            const int i=ii[k], j=jj[k];
            ERR_FAIL_INDEX(i,N); ERR_FAIL_INDEX(j,N);
            Vector2 difference=points[i]-points[j];
            const double length=difference.length();
            if (length<0.001) continue;
            const double rest=lengths[k], error=length-rest, limit=rest*compression;
            if (std::abs(error)>limit) {
                const Vector2 correction=difference/real_t(length)*real_t(error-std::clamp(error,-limit,limit))*real_t(0.5);
                points[i]-=correction; points[j]+=correction;
                continue;
            }
            const double alpha=double(compliance[k])/(dt*dt);
            const double dl=(-(length-rest)-alpha*lambda[k])/(2.0*weight+alpha);
            lambda[k]=float(double(lambda[k])+dl);
            const Vector2 correction=difference/real_t(length)*real_t(weight*dl);
            points[i]+=correction; points[j]-=correction;
        }
        Vector2 gradients[N];
        double denominator=0, rest_area=s["area"];
        const double scale=std::sqrt(std::abs(rest_area));
        ERR_FAIL_COND(scale<=0);
        for (int i=0;i<N;++i) {
            const Vector2 d=points[(i+1)%N]-points[(i+N-1)%N];
            gradients[i]=Vector2(d.y,-d.x)*real_t(0.5)/real_t(scale);
            denominator+=weight*double(gradients[i].length_squared());
        }
        const double alpha=area_compliance/(dt*dt), area_lambda=s["area_lambda"];
        const double dl=(-(area(p)-rest_area)/scale-alpha*area_lambda)/(denominator+alpha);
        s["area_lambda"]=area_lambda+dl;
        for (int i=0;i<N;++i) points[i]+=gradients[i]*real_t(weight*dl);
        s["points"]=p; s["edge_lambdas"]=lambdas; s["surface_dirty"]=true;
    }
    PackedVector2Array surface(Dictionary s) {
        if (!bool(s["surface_dirty"])) return s["contact_surface"];
        PackedVector2Array result=mapped_surface(s,s["sectors"]);
        ERR_FAIL_COND_V(result.is_empty(),result);
        Vector2 minimum=result[0], maximum=minimum;
        for (int i=0;i<result.size();++i) {
            minimum=minimum.min(result[i]); maximum=maximum.max(result[i]);
        }
        s["surface_bounds"]=Rect2(minimum,maximum-minimum);
        s["contact_surface"]=result; s["surface_dirty"]=false; s["query_dirty"]=true;
        return result;
    }
    PackedVector2Array mapped_surface(const Dictionary &s, const Array &sectors) {
        PackedVector2Array points=s["points"], result;
        const Vector2 c=center(points);
        ERR_FAIL_COND_V(points.size()!=N || sectors.size()!=N,result);
        for (int i=0;i<N;++i) {
            Transform2D mapping(points[i]-c,points[(i+1)%N]-c,c);
            PackedVector2Array sector=sectors[i];
            for (int j=0;j<sector.size();++j) result.push_back(mapping.xform(sector[j]));
        }
        return result;
    }
    TypedArray<int64_t> support(const PackedVector2Array &points, Vector2 axis) {
        double best=-std::numeric_limits<double>::infinity();
        for (int i=0;i<points.size();++i) best=std::max(best,double(points[i].dot(axis)));
        TypedArray<int64_t> indices;
        for (int i=0;i<points.size();++i) if (best-double(points[i].dot(axis))<1.5) indices.push_back(i);
        return indices;
    }
    PackedFloat32Array surface_gradient(Dictionary s, const TypedArray<int64_t> &indices) {
        return gradient_from_bindings(s["outline_bindings"],indices);
    }
    PackedFloat32Array gradient_from_bindings(const Array &bindings, const TypedArray<int64_t> &indices) {
        PackedFloat32Array weights; weights.resize(N); weights.fill(0);
        float *w=weights.ptrw();
        for (int k=0;k<indices.size();++k) {
            const int index=int64_t(indices[k]);
            ERR_FAIL_INDEX_V(index,bindings.size(),weights);
            const Vector4 binding=bindings[index];
            const double base=(1.0-double(binding.z)-double(binding.w))/N/indices.size();
            for (int i=0;i<N;++i) w[i]=float(double(w[i])+base);
            w[int(binding.x)]=float(double(w[int(binding.x)])+double(binding.z)/indices.size());
            w[int(binding.y)]=float(double(w[int(binding.y)])+double(binding.w)/indices.size());
        }
        return weights;
    }
    Vector2 weighted(const PackedVector2Array &points, const PackedFloat32Array &weights) {
        ERR_FAIL_COND_V(points.size()!=N || weights.size()!=N,Vector2());
        Vector2 result;
        for (int i=0;i<N;++i) result+=points[i]*weights[i];
        return result;
    }
    void correct_surface(Dictionary s, const PackedFloat32Array &weights, Vector2 correction, double stabilization) {
        PackedVector2Array p=s["points"], previous=s["previous"];
        ERR_FAIL_COND(p.size()!=N || previous.size()!=N || weights.size()!=N);
        Vector2 *points=p.ptrw(), *prev=previous.ptrw();
        for (int i=0;i<N;++i) {
            const Vector2 shift=correction*weights[i];
            points[i]+=shift; prev[i]+=shift*real_t(stabilization);
        }
        s["points"]=p; s["previous"]=previous; s["surface_dirty"]=true;
    }
    bool resolve_contact(Dictionary a, Dictionary b, Dictionary m, double wa, double wb) {
        const Vector2 normal=m["normal"];
        const PackedFloat32Array ga=m["ga"], gb=m["gb"];
        ERR_FAIL_COND_V(ga.size()!=N || gb.size()!=N,false);
        const double depth=double(m["margin"])-double((weighted(b["points"],gb)-weighted(a["points"],ga)).dot(normal));
        if (depth < -0.02) return false;
        double denominator=0;
        for (int i=0;i<N;++i) denominator+=wa*double(ga[i])*ga[i]+wb*double(gb[i])*gb[i];
        const double dl=std::max(depth,0.0)/std::max(denominator,0.000001);
        const Vector2 va=weighted(a["velocities"],ga), vb=weighted(b["velocities"],gb);
        const double allowed=std::max(1.0,std::max(0.0,-double((vb-va).dot(normal)))*double(a["step_dt"]));
        const double stabilization=std::clamp((depth-allowed)/std::max(depth,0.000001),0.0,1.0);
        correct_surface(a,ga,-normal*real_t(wa)*real_t(dl),stabilization);
        correct_surface(b,gb,normal*real_t(wb)*real_t(dl),stabilization);
        return true;
    }
};

static void initialize(ModuleInitializationLevel level) {
    if (level==MODULE_INITIALIZATION_LEVEL_SCENE) ClassDB::register_class<XPBDPondKernel>();
}
static void uninitialize(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT xpbd_pond_library_init(
    GDExtensionInterfaceGetProcAddress get_proc_address, GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc_address,library,initialization);
    init.register_initializer(initialize);
    init.register_terminator(uninitialize);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
