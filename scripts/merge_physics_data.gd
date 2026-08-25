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
## 접촉한 공이 충분히 느린 상태를 유지하면 물리적으로 잠들게 해 잔떨림을 멈춘다.
@export var sleep_assist_enabled := true
@export_range(0.0, 2.0, 0.05) var sleep_assist_settle_time := 0.35
@export_range(0.0, 20.0, 0.5) var sleep_assist_linear_speed := 4.0
