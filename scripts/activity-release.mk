# Shared by both Makefiles. Fail before ANY recipe/prerequisite or version bump.
# Local test/build targets remain available; publication is held by the live registry.
ACTIVITY_PUBLICATION_GOALS := release release-all deploy-all deploy-test deploy-pages deploy-hugo deploy-stable deploy-app-hosting deploy-functions deploy-rules ftp-upload ftp-upload-hugo ftp-upload-app-redirect bump-version
ifneq ($(filter $(ACTIVITY_PUBLICATION_GOALS),$(MAKECMDGOALS)),)
ifneq ($(shell python3 scripts/activity_plan.py gate >/dev/null 2>&1; echo $$?),0)
$(error RELEASE BLOCKED by docs/plans/systemic-ux/activity.json; run 'make activity-status')
endif
endif
