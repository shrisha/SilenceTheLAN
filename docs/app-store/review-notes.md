# App Review Notes Template

SilenceTheLAN manages existing UniFi firewall rules on a local network.

Important context for review:
- The app requires access to a UniFi controller on the same LAN.
- It does not create or delete firewall rules.
- It only toggles and temporarily overrides existing rules configured by the user.

Reviewer test path:
1. Open app and complete onboarding.
2. Discover local UniFi controller.
3. Sign in with local admin account.
4. Select detected rules.
5. Toggle a rule and confirm status change.
6. Long-press a rule and select a temporary extension.

Demo credentials and environment:
- Controller Host: TODO
- Username: TODO
- Password: TODO
- Additional instructions: TODO

If no live test environment is provided, include a short demo video URL here:
- Demo video: TODO
