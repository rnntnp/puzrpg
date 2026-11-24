shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D ownership : filter_nearest, repeat_disable;
uniform sampler2D previous_field : filter_nearest, repeat_disable;
uniform bool seed_pass = false;
uniform float jump = 1.0;

// RGBA8 losslessly stores two 16-bit pixel coordinates. Zero means invalid.
vec4 pack_point(vec2 point) {
	vec2 q=floor(point)+vec2(1.0);
	return vec4(floor(q.x/256.0),mod(q.x,256.0),floor(q.y/256.0),mod(q.y,256.0))/255.0;
}
vec2 unpack_point(vec4 packed) {
	vec4 q=floor(packed*255.0+0.5);
	return vec2(q.x*256.0+q.y,q.z*256.0+q.w)-vec2(1.0);
}
float priority(vec3 id) {return dot(id,vec3(1.0,255.0,65025.0));}

void fragment() {
	vec2 size=vec2(textureSize(ownership,0));
	vec2 p=floor(UV*size);
	vec2 center=(p+vec2(0.5))/size;
	vec4 own=texture(ownership,center);
	vec2 best=vec2(-1.0);
	float best_distance=1e20;
	if (own.a>0.5) {
		for (int y=-1;y<=1;y++) {
			for (int x=-1;x<=1;x++) {
				vec2 q=p+vec2(float(x),float(y))*(seed_pass?1.0:jump);
				if (any(lessThan(q,vec2(0.0))) || any(greaterThanEqual(q,size))) {continue;}
				vec2 uv=(q+vec2(0.5))/size;
				if (seed_pass) {
					vec4 other=texture(ownership,uv);
					if (other.a>0.5 && priority(other.rgb)>priority(own.rgb)+0.002) {best=p;}
				} else {
					vec2 candidate=unpack_point(texture(previous_field,uv));
					if (candidate.x<0.0 || candidate.y<0.0) {continue;}
					vec4 candidate_owner=texture(ownership,(candidate+vec2(0.5))/size);
					if (candidate_owner.a<0.5 || distance(candidate_owner.rgb,own.rgb)>0.002) {continue;}
					float d=dot(candidate-p,candidate-p);
					if (d<best_distance) {best_distance=d;best=candidate;}
				}
			}
		}
	}
	COLOR=best.x>=0.0?pack_point(best):vec4(0.0);
}
