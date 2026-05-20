# 에이전트 작업 지침

이 저장소에서 의미 있는 작업을 할 때는 반드시 `harness-apply` 스킬을 사용한다.

시작 순서:
1. `harness/manifest.json`을 읽는다.
2. `harness/specs/`에서 활성 기능 명세 `feature-merge-camp-mvp.md`를 읽는다.
3. manifest의 `approvedPacks`를 확인한다. 비어 있으면 `suggestedPacks`는 참고용으로만 취급한다.
4. 코드 변경 전에 연결된 ADR과 계약 문서를 읽는다.
5. `harness/rules/constraints.md`와 `harness/rules/golden-rules.md`를 읽는다.

응답 계약:
- `References used`, `Constraints`, `Conflicts or gaps`, `Escalation`을 반드시 포함한다.
- 필요한 하네스 산출물이 없거나 충돌하면 즉시 에스컬레이션한다.
- 어떤 승인된 팩 또는 제안 팩을 사용했는지 명시한다.
