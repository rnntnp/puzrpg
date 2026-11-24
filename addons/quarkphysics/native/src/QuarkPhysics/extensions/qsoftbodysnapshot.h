#ifndef QSOFTBODYSNAPSHOT_H
#define QSOFTBODYSNAPSHOT_H
#include "../qbody.h"
#include "../qmesh.h"
#include <algorithm>
#include <cmath>

// One boundary crossing per body: constrain and read the same physical
// particles. This is an opt-in bridge; it does not replace Quark's solver.
struct QSoftBodySnapshot {
    std::vector<QVector> points,velocities;
    static QSoftBodySnapshot Read(QBody *body,float dt,float radius,float softRatio,float hardRatio,float rate,bool limit,float internalDamping=0.0f,const std::vector<QVector> &rest={},float deformationLimit=0.0f) {
        QSoftBodySnapshot result;
        std::vector<QParticle*> particles;
        std::vector<QVector> previous;
        QVector center=QVector::Zero(),meanVelocity=QVector::Zero();
        for(auto mesh:*body->GetMeshes()) for(int i=0;i<mesh->GetParticleCount();++i) {
            auto p=mesh->GetParticleAt(i); particles.push_back(p);
            result.points.push_back(p->GetGlobalPosition());
            previous.push_back(p->GetPreviousGlobalPosition());
            center+=result.points.back();
            meanVelocity+=result.points.back()-previous.back();
        }
        if(particles.empty()) return result;
        float inverseCount=1.0f/particles.size();
        center=center*inverseCount; meanVelocity=meanVelocity*inverseCount;
        if(limit) {
            float hard=radius*hardRatio,soft=std::min(radius*softRatio,hard);
            float span=std::max(hard-soft,0.001f),blend=1.0f-std::exp(-rate*dt);
            auto limited=result.points;
            QVector limitedCenter=QVector::Zero();
            for(size_t i=0;i<particles.size();++i) {
                auto offset=result.points[i]-center;
                float distance=offset.Length();
                if(distance>soft) {
                    float excess=distance-soft;
                    float target=std::min(hard,distance-blend*excess*excess/(span+excess));
                    limited[i]=center+offset*(target/distance);
                }
                limitedCenter+=limited[i];
            }
            auto shift=center-limitedCenter*inverseCount;
            float maximum=0.0f;
            for(auto &point:limited) {point+=shift;maximum=std::max(maximum,(point-center).Length());}
            float scale=std::min(1.0f,hard/std::max(maximum,0.001f));
            for(size_t i=0;i<particles.size();++i) {
                auto position=center+(limited[i]-center)*scale;
                if((position-result.points[i]).LengthSquared()<0.000001f) continue;
                auto relative=result.points[i]-previous[i]-meanVelocity;
                auto radial=(position-center).Normalized();
                float t=std::max(0.0f,std::min(1.0f,((result.points[i]-center).Length()-soft)/span));
                float damping=t*t*(3.0f-2.0f*t);
                relative-=radial*(std::max(0.0f,relative.Dot(radial))*damping);
                previous[i]=position-meanVelocity-relative;
                result.points[i]=position;
                particles[i]->SetGlobalPosition(position);
                particles[i]->SetPreviousGlobalPosition(previous[i]);
            }
        }
        if(deformationLimit>0.0f && rest.size()==particles.size()) {
            // Limit both compression and stretch against the matched rest
            // outline, rather than only limiting the outer centroid radius.
            center=QVector::Zero(); QVector restCenter=QVector::Zero();
            for(size_t i=0;i<particles.size();++i) {center+=result.points[i];restCenter+=rest[i];}
            center=center*inverseCount;restCenter=restCenter*inverseCount;
            float cross=0.0f,dot=0.0f;
            for(size_t i=0;i<particles.size();++i) {
                auto a=rest[i]-restCenter,b=result.points[i]-center;
                cross+=a.x*b.y-a.y*b.x;dot+=a.Dot(b);
            }
            float angle=std::atan2(cross,dot),c=std::cos(angle),s=std::sin(angle);
            float hard=radius*deformationLimit,soft=hard*0.5f;
            float span=std::max(hard-soft,0.001f),blend=1.0f-std::exp(-rate*dt);
            std::vector<QVector> targets,limited;
            QVector average=QVector::Zero();
            for(size_t i=0;i<particles.size();++i) {
                auto r=rest[i]-restCenter;
                auto target=center+QVector(r.x*c-r.y*s,r.x*s+r.y*c);
                auto delta=result.points[i]-target;
                float distance=delta.Length();
                if(distance>soft) {
                    float excess=distance-soft;
                    float length=std::min(hard,distance-blend*excess*excess/(span+excess));
                    delta=delta*(length/distance);
                }
                targets.push_back(target);limited.push_back(target+delta);average+=limited.back();
            }
            auto shift=center-average*inverseCount;
            float maximum=0.0f;
            for(size_t i=0;i<particles.size();++i) {limited[i]+=shift;maximum=std::max(maximum,(limited[i]-targets[i]).Length());}
            float scale=std::min(1.0f,hard/std::max(maximum,0.001f));
            for(size_t i=0;i<particles.size();++i) {
                auto position=targets[i]+(limited[i]-targets[i])*scale;
                previous[i]+=position-result.points[i];
                result.points[i]=position;
                particles[i]->SetGlobalPosition(position);particles[i]->SetPreviousGlobalPosition(previous[i]);
            }
        }
        if(internalDamping>0.0f) {
            // Project displacement onto translation + rigid rotation. Dampen
            // only the residual so a moving/rolling ball does not feel stuck.
            center=QVector::Zero(); meanVelocity=QVector::Zero();
            for(size_t i=0;i<particles.size();++i) {
                center+=result.points[i]; meanVelocity+=result.points[i]-previous[i];
            }
            center=center*inverseCount; meanVelocity=meanVelocity*inverseCount;
            float angular=0.0f,inertia=0.0f;
            for(size_t i=0;i<particles.size();++i) {
                auto r=result.points[i]-center,v=result.points[i]-previous[i]-meanVelocity;
                angular+=r.x*v.y-r.y*v.x; inertia+=r.LengthSquared();
            }
            angular/=std::max(inertia,0.000001f);
            float retention=std::exp(-internalDamping*dt);
            for(size_t i=0;i<particles.size();++i) {
                auto r=result.points[i]-center;
                auto rigid=meanVelocity+QVector(-r.y,r.x)*angular;
                auto residual=result.points[i]-previous[i]-rigid;
                previous[i]=result.points[i]-rigid-residual*retention;
                particles[i]->SetPreviousGlobalPosition(previous[i]);
            }
        }
        float inverseDt=1.0f/std::max(dt,0.000001f);
        for(size_t i=0;i<particles.size();++i) result.velocities.push_back((result.points[i]-previous[i])*inverseDt);
        return result;
    }
};
#endif
