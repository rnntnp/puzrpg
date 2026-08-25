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

@export_category("공 관성")
## 공의 직선 이동이 얼마나 빨리 잦아드는지 결정한다. 마찰과 달리 굴러가는 관성에도 적용된다.
@export_range(0.0, 10.0, 0.1) var ball_linear_damp: float = 2.0
## 공의 회전이 얼마나 빨리 잦아드는지 결정한다.
@export_range(0.0, 10.0, 0.1) var ball_angular_damp: float = 4.0

@export_category("Sleep Assist")
## 접촉한 공의 위치가 측정 시간 동안 거의 변하지 않으면 잠들게 해 잔떨림을 멈춘다.
@export var sleep_assist_enabled := true
@export_range(0.0, 3.0, 0.05) var sleep_assist_settle_time := 1.5
## 측정 시작 위치에서 이 거리(px) 안에 계속 머문 공만 잠든다.
@export_range(0.0, 30.0, 0.1) var sleep_assist_max_displacement := 1.5
