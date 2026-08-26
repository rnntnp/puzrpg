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
@export_range(0.0, 30.0, 0.1) var ball_angular_damp: float = 4.0

@export_category("공 접촉 안정화")
## 바닥이나 다른 공에 닿아 있을 때만 수평 미끄러짐을 줄인다. 공중 낙하에는 적용되지 않는다.
@export_range(0.0, 20.0, 0.1) var contact_horizontal_damp: float = 0.0
## 비원형 외곽에서 반복해서 생기는 회전 토크를 접촉 중에만 줄인다.
@export_range(0.0, 30.0, 0.1) var contact_angular_damp: float = 0.0
## 접촉 중 허용할 최대 회전 속도(rad/s)다. 0이면 제한하지 않는다.
@export_range(0.0, 20.0, 0.1) var contact_max_angular_speed: float = 0.0

@export_category("미세 깨움 억제")
## 잠든 공이 작은 접촉 변화로 깨어났을 때 실제 충격인지 짧게 관찰한다.
@export var micro_wake_guard_enabled := true
@export_range(0.0, 0.5, 0.01) var micro_wake_grace_time := 0.08
## 유예 시간 동안 이 속도(px/s)를 넘으면 실제 충격으로 보고 깨어 있게 둔다.
@export_range(0.0, 100.0, 0.5) var micro_wake_linear_threshold := 14.0
## 유예 시간 동안 이 회전 속도(rad/s)를 넘으면 실제 충격으로 본다.
@export_range(0.0, 5.0, 0.05) var micro_wake_angular_threshold := 0.35

@export_category("Sleep Assist")
## 접촉한 공의 위치가 측정 시간 동안 거의 변하지 않으면 잠들게 해 잔떨림을 멈춘다.
@export var sleep_assist_enabled := true
@export_range(0.0, 3.0, 0.05) var sleep_assist_settle_time := 1.5
## 측정 시작 위치에서 이 거리(px) 안에 계속 머문 공만 잠든다.
@export_range(0.0, 30.0, 0.1) var sleep_assist_max_displacement := 1.5
