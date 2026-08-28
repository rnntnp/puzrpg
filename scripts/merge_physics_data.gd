class_name MergePhysicsData
extends Resource

@export_category("벽 물리")
@export_range(0.0, 1.0, 0.01) var wall_friction: float = 0.0
@export_range(0.0, 1.0, 0.01) var wall_bounce: float = 0.0

@export_category("바닥 물리")
@export_range(0.0, 1.0, 0.01) var floor_friction: float = 0.35
@export_range(0.0, 1.0, 0.01) var floor_bounce: float = 0.0

@export_category("공 접촉 물리")
## 공-공 및 공-지형 접촉에서 사용할 마찰입니다.
@export_range(0.0, 1.0, 0.01) var ball_friction: float = 0.8
## 공이 다른 공이나 지형과 충돌할 때 유지할 반동입니다.
@export_range(0.0, 1.0, 0.01) var ball_bounce: float = 0.0

@export_category("공 관성")
## 공의 직선 이동이 얼마나 빨리 잦아드는지 결정한다. 마찰과 달리 굴러가는 관성에도 적용된다.
@export_range(0.0, 10.0, 0.01) var ball_linear_damp: float = 2.0
## 공의 회전이 얼마나 빨리 잦아드는지 결정한다.
@export_range(0.0, 30.0, 0.01) var ball_angular_damp: float = 4.0

@export_category("공 질량")
## 켜면 공 반지름에 비례해 질량을 계산하고, 끄면 모든 기본 공에 고정 질량을 사용한다.
@export var use_radius_scaled_mass := false
@export_range(0.01, 20.0, 0.01) var fixed_ball_mass: float = 1.0
## 반지름을 이 값으로 나눈 결과를 질량으로 사용한다.
@export_range(1.0, 100.0, 0.5) var ball_mass_radius_divisor: float = 20.0
@export_range(0.01, 20.0, 0.01) var minimum_ball_mass: float = 1.0

@export_category("공 수면")
## false면 공이 정지해도 물리 수면에 들어가지 않는다.
@export var ball_can_sleep := true

@export_category("보드 정지 판정")
## 이 속도보다 빠른 공이 하나라도 있으면 보드가 계속 움직이는 것으로 본다.
@export_range(0.0, 30.0, 0.1) var settled_linear_speed: float = 8.0
## 이 회전 속도보다 빠른 공이 하나라도 있으면 보드가 계속 움직이는 것으로 본다.
@export_range(0.0, 2.0, 0.01) var settled_angular_speed: float = 0.2


func get_ball_mass(radius: float) -> float:
	if use_radius_scaled_mass:
		return maxf(minimum_ball_mass, radius / maxf(1.0, ball_mass_radius_divisor))
	return maxf(0.01, fixed_ball_mass)
