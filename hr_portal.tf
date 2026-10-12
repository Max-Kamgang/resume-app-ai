# ─────────────────────────────────────────────
# HR portal credentials
#
# The internal portal at /admin is where the match score, the AI reasoning and
# the override controls live. Nothing the candidate receives contains a score,
# so this login is the only way into that information.
#
# Both values below must be IDENTICAL on every instance:
#   - the password, obviously;
#   - the session key, because the ALB sends a given HR user to either server,
#     and a per-boot key would invalidate their cookie on the next request.
#
# They travel through user-data into /opt/rp-app/.env (umask 077, chmod 600),
# exactly like the Gemini key, and never ship to S3 with the application code.
# ─────────────────────────────────────────────

# special = false on purpose: the value is written into a systemd
# EnvironmentFile and read by a shell heredoc, where "$" or a backtick would
# be interpreted rather than stored.
resource "random_password" "hr_portal" {
  length  = 20
  special = false
}


resource "random_password" "session_secret" {
  length  = 48
  special = false
}


locals {
  # No login supplied: one "hr" account, password printed by
  #   terraform output -raw hr_portal_password
  hr_portal_users = length(var.hr_portal_users) > 0 ? var.hr_portal_users : {
    hr = random_password.hr_portal.result
  }

  # base64, because systemd's EnvironmentFile parser strips the quotes out of
  # raw JSON and would hand the application {hr:password} instead of
  # {"hr":"password"}. app.py decodes it on startup.
  hr_portal_users_b64 = base64encode(jsonencode(local.hr_portal_users))

  # The usernames are not secret; only the passwords are. Terraform propagates
  # the sensitive mark to anything derived from the map, so it has to be lifted
  # explicitly for the outputs to be printable.
  hr_portal_usernames = nonsensitive(keys(local.hr_portal_users))
}
