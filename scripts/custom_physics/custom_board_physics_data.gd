class_name CustomBoardPhysicsData
extends Resource

@export_category("고정 스텝")
## 렌더링 FPS와 무관하게 이 빈도로 보드 물리를 계산한다.
@export_range(30, 240, 1) var simulation_hz: int = 60
## 한 프레임이 늦어졌을 때 따라잡을 최대 고정 스텝 수다.
@export_range(1, 12, 1) var maximum_substeps: int = 4
## 겹침과 접촉 속도를 반복해서 보정하는 횟수다.
@export_range(1, 16, 1) var solver_iterations: int = 8

@export_category("이동")
## Godot 기본 2D 중력과 같은 기준값이며 레벨의 물리 배속 제곱이 곱해진다.
@export_range(100.0, 3000.0, 10.0) var gravity: float = 980.0
@export_range(0.0, 5.0, 0.01) var linear_damping_per_second: float = 0.08
@export_range(0.0, 5.0, 0.01) var angular_damping_per_second: float = 0.10

@export_category("충돌")
@export_range(0.0, 1.0, 0.01) var ball_restitution: float = 0.03
@export_range(0.0, 1.0, 0.01) var wall_restitution: float = 0.03
@export_range(0.0, 1.0, 0.01) var floor_restitution: float = 0.01
@export_range(0.0, 2.0, 0.01) var ball_friction: float = 0.26
@export_range(0.0, 2.0, 0.01) var wall_friction: float = 0.12
@export_range(0.0, 2.0, 0.01) var floor_friction: float = 0.34
@export_range(100.0, 10000.0, 10.0) var shared_rotational_inertia: float = 1200.0
@export_range(0.0, 1.0, 0.01) var position_correction: float = 0.82
@export_range(0.0, 4.0, 0.05) var penetration_slop: float = 0.5

@export_category("수면")
@export_range(0.0, 30.0, 0.1) var sleep_linear_speed: float = 2.5
@export_range(0.0, 3.0, 0.01) var sleep_angular_speed: float = 0.08
@export_range(0.0, 3.0, 0.05) var sleep_delay: float = 0.9
@export_range(0.0, 100.0, 0.5) var wake_relative_speed: float = 8.0
@export_range(0.0, 10.0, 0.1) var wake_penetration: float = 1.5

@export_category("끼임 해소 / Jam Slip")
## 오래 유지된 접촉의 압력을 저장했다가 기존 미세 불균형 방향으로만 방출한다.
@export var jam_slip_enabled := true
@export_range(0.0, 5.0, 0.05) var jam_minimum_contact_age: float = 0.9
## 한 고정 스텝의 접촉 충격량 중 저장할 비율이다.
@export_range(0.0, 1.0, 0.01) var jam_pressure_storage_ratio: float = 0.02
@export_range(0.0, 500.0, 1.0) var jam_maximum_stored_energy: float = 80.0
@export_range(0.0, 500.0, 0.5) var jam_minimum_release_energy: float = 8.0
## 보드 운동에너지가 이 값보다 낮을 때만 압력 방출을 허용한다.
@export_range(0.0, 10000.0, 10.0) var jam_kinetic_energy_threshold: float = 450.0
@export_range(0.0, 10.0, 0.05) var jam_energy_to_impulse: float = 5.0
@export_range(0.0, 100.0, 0.5) var jam_maximum_release_impulse: float = 100.0
@export_range(0.0, 1.0, 0.01) var jam_release_energy_fraction: float = 1.0
@export_range(0.0, 2.0, 0.01) var jam_release_cooldown: float = 1.2
## 방출된 바로 그 접촉의 마찰만 잠시 낮춰 힘이 즉시 재흡수되지 않게 한다.
@export_range(0.0, 1.0, 0.01) var jam_slip_friction_multiplier: float = 0.0
@export_range(0.0, 0.5, 0.01) var jam_slip_duration: float = 0.3
## 접촉 합력의 접선 성분이 이 값보다 작으면 새 방향을 만들지 않고 방출하지 않는다.
@export_range(0.0, 10.0, 0.01) var jam_direction_epsilon: float = 0.12
@export_range(0.0, 4.0, 0.05) var jam_contact_load_bias_scale: float = 1.0

@export_category("끼임 마찰 완화")
@export_range(0.0, 5.0, 0.05) var jam_friction_weakening_delay: float = 0.8
@export_range(0.0, 1.0, 0.01) var jam_friction_weakening_per_second: float = 0.12
@export_range(0.0, 1.0, 0.01) var jam_minimum_friction_multiplier: float = 0.6
