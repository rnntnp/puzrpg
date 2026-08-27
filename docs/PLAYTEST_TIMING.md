# 플레이테스트 스테이지 시간 기록

디버그 빌드를 `--playtest-timing` 옵션과 함께 실행한 경우에만 적 처치 시간과 스테이지 시도 결과를 기록한다. 게임 UI에는 표시하지 않는다.

## 실행 방법

Windows에서는 저장소 루트에서 전용 실행기를 사용한다.

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_playtest_timing.ps1
```

실행하면 Godot 에디터가 아니라 게임이 바로 열린다. PowerShell 창은 측정 로그를 보여 주므로 게임이 끝날 때까지 닫지 않는다.

Godot 실행 파일을 자동으로 찾지 못하면 경로를 지정한다.

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_playtest_timing.ps1 `
  -GodotExecutable "C:\path\to\Godot.exe"
```

Godot을 직접 실행할 때는 사용자 인수 구분자 `--` 뒤에 옵션을 전달한다.

```powershell
Godot.exe --path . -- --playtest-timing
```

일반 에디터 실행과 옵션 없는 디버그 실행에서는 기록하지 않는다.

## 기록 위치

- Godot 경로: `user://playtest_stage_timings.csv`
- 실제 경로는 실행 로그의 `[PLAYTEST TIMING] START` 항목에 출력된다.

릴리스 빌드에서는 옵션 유무와 관계없이 기록기를 비활성화한다. 활성화된 플레이테스트에서 기존 CSV는 덮어쓰지 않고 행을 이어 붙인다.

## 시간 기준

- Enemy 1 `segment_seconds`: 전투 시작부터 Enemy 1 처치까지
- Enemy 2 이상 `segment_seconds`: 이전 적 처치 후 다음 전투가 시작된 시점부터 해당 적 처치까지
- `cumulative_seconds`: 스테이지의 모든 활성 전투 구간 누적 시간
- 시작 연출, 적 처치 애니메이션, 적 교대 대기, 일시정지 메뉴 시간은 제외한다.
- 전투 도중 입력을 잠그는 튜토리얼과 기믹 연출 시간은 포함한다.

## CSV 이벤트

- `enemy_defeated`: 적을 처치했을 때 구간 시간과 누적 시간 기록
- `stage_completed`: 모든 적 처치 완료
- `player_defeated`: 플레이어 체력 소진
- `board_game_over`: 머지 보드 게임오버
- `gimmick_failed`: 기믹의 명시적 실패
- `abandoned`: 결과를 내지 않고 전투 화면에서 이탈

`control_mode`은 `manual` 또는 `autoplay`이며, 자동 플레이 결과를 수동 플레이 결과와 분리할 때 사용한다.
