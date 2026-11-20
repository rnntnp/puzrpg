# GitHub Pages 배포

## 배포 대상

- 주소: https://rnntnp.github.io/puzrpg/
- 저장소: https://github.com/rnntnp/puzrpg
- 배포 브랜치: `gh-pages` 루트의 `index.html` 및 Godot 웹 산출물. 소스 브랜치를 푸시하는 것만으로는 배포되지 않는다.
- 현재 공개 목록: 캠페인 1~5, **62. 동글한 연못**. `resources/catalogs/main_level_catalog.tres`의 `web_release_level_paths`에서 순서를 관리한다.
- `.tres`를 직접 편집할 때 `web_release_level_paths`는 `script = ExtResource("1_catalog")` 다음에 둔다. 스크립트 연결 전에 속성을 쓰면 공개 목록이 적용되지 않을 수 있다.
- `release_web` 기능 태그일 때만 공개 목록을 사용한다. 개발용 목록과 테스트 등록은 유지한다. 테스트 레벨은 기존 규칙에 따라 항상 선택 가능하다.

## 웹 내보내기 설정

`export_presets.cfg`의 `Web` 프리셋을 사용한다.

- Godot **4.7.1**과 같은 버전의 웹 export templates 필요.
- `custom_features="release_web"`, 스레드 및 Extensions Support 비활성화.
- `addons/quarkphysics/*`, `addons/xpbd_pond/*`는 웹 내보내기에서 제외한다. 현재 템플릿은 GDExtension을 지원하지 않는다. 이를 포함하면 시작 화면에서 `GDExtension libraries are not supported`로 실행이 중단된다.
- 62번은 Godot 강체와 GDScript 시각 레이어를 사용하며 네이티브 확장이 필요 없다.
- `resources/levels/test_*`를 일괄 제외하지 않는다. 그러면 62번 리소스까지 빠진다. 공개 메뉴 노출은 카탈로그의 웹 목록으로 제한한다.
- 커스텀 물리 실험실과 개발 전용 장면 등의 기존 제외 설정, `web/web_shell.html`은 유지한다.

## 배포 절차 (PowerShell)

프로젝트 루트에서 실행한다. 웹 빌드는 **현재 작업 폴더의 미커밋 변경도 포함**한다. 소스 작업을 보존하기 위해 배포용 Git 폴더를 따로 사용하고, 소스 브랜치에는 자동 커밋하지 않는다.

1. 새 산출물 폴더를 만들고 내보낸다. 아래 실행 파일 경로는 현재 PC 기준이며 설치 위치에 맞게 바꾼다. 이전 산출물이 섞이지 않도록 새 폴더명을 사용한다.

```powershell
$webOutput = "build/web-$(Get-Date -Format yyyyMMdd-HHmmss)"
New-Item -ItemType Directory -Path $webOutput | Out-Null
$godotExe = 'C:/Program Files/Godot/Godot.exe.exe'
$exportArgs = @('--headless', '--path', (Get-Location).Path, '--export-release', 'Web', "$webOutput/index.html")
$exportProcess = Start-Process -FilePath $godotExe -ArgumentList $exportArgs -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput "$webOutput/export.log" -RedirectStandardError "$webOutput/export-errors.log"
if ($exportProcess.ExitCode -ne 0) { throw 'Web export failed' }
Get-Content "$webOutput/export-errors.log"
Select-String -Path "$webOutput/index.html" -Pattern 'gdextensionLibs'
./tools/version_web_pack.ps1 -WebDirectory $webOutput
```

`gdextensionLibs`는 `[]`여야 한다. 종료 코드가 0이어도 로그의 스크립트/리소스 오류를 확인한다. 현재 프리셋의 필수 산출물은 `index.html`, `index.js`, `index.pck`, `index.wasm`, `index.png`, `index.icon.png`, `index.apple-touch-icon.png`, 두 `index.audio.*.js` 파일이다.

`version_web_pack.ps1`는 팩의 SHA-256을 다운로드 URL에 붙인다. 파일 크기가 같은 재배포에서도 이전 팩 캐시를 재사용하지 않도록 매번 내보내기 후 실행한다.

2. 배포 브랜치를 별도 폴더에 받는다. 처음에는 다음을 실행한다. `build/pages-deploy`가 이미 있다면 그 폴더가 올바른 저장소의 `gh-pages`이며 깨끗한지 확인하고 `git -C build/pages-deploy pull --ff-only origin gh-pages`로 갱신한다.

```powershell
git clone --single-branch --branch gh-pages https://github.com/rnntnp/puzrpg.git build/pages-deploy
```

3. 내보낸 파일만 복사하고 검토 후 커밋·푸시한다. `.nojekyll`은 유지하며 로그, `.import`, 로컬 서버 파일은 배포하지 않는다.

```powershell
Copy-Item -Path "$webOutput/index.*" -Destination build/pages-deploy -Exclude '*.import'
git -C build/pages-deploy status --short
git -C build/pages-deploy add index.html index.js index.pck index.wasm index.png index.icon.png index.apple-touch-icon.png index.audio.worklet.js index.audio.position.worklet.js
git -C build/pages-deploy diff --cached --stat
git -C build/pages-deploy commit -m 'Deploy current web build'
git -C build/pages-deploy push origin gh-pages
```

정상 push를 사용하고 강제 push하지 않는다. 충돌하면 원격 변경을 먼저 확인한다. 프리셋 변경으로 추가 산출물이 생기면 HTML이 참조하는 파일도 함께 배포한다. 일반 Git은 단일 파일 100 MiB 이상을 거부하므로 `index.pck`가 커지면 사용하지 않는 자산을 제외해야 한다.

## 배포 후 확인

- Pages 반영에는 잠시 시간이 걸린다. GitHub Actions의 Pages 배포 상태와 공개 URL을 확인한다. 공개 Pages API가 404여도 배포 실패라고 단정하지 않는다.
- 공개 HTML의 `fileSizes.index.pck`가 로컬 산출물 크기와 같은지 확인한다. 파일 HTTP 200만으로 실행 성공을 판단하지 않는다.
- 브라우저에서 로딩 → 레벨 선택 → 1스테이지 진입·낙하·병합을 확인한다.
- 공개 목록 마지막의 **62. 동글한 연못** 진입, 상향 발사, 공 표시·접촉, 컷아웃 주인공을 확인한다. 콘솔의 새 스크립트/셰이더 오류도 확인한다.
- 오래된 화면이 보이면 `Ctrl+F5` 또는 배포 커밋을 붙인 `?deploy=<commit>` URL로 갱신한다. 모바일·전체 레벨·게임성 검증은 별도 확인 범위다.

## 복구

배포 폴더에서 문제 배포 커밋을 `git revert`하고 `gh-pages`에 정상 push하면 이전 산출물로 돌아간다. 여러 커밋이 한 배포를 이뤘다면 해당 커밋들을 모두 확인한다. 소스 작업 폴더를 초기화하거나 강제 push할 필요는 없다.
