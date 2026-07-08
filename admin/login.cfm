<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Login</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">

  <link rel="stylesheet" href="/assets/css/admin.css">
</head>

<body class="bg-light">

  <div class="container min-vh-100 d-flex align-items-center justify-content-center">
    <div class="card shadow-sm admin-login-card">
      <div class="card-body p-4">

        <h4 class="text-center mb-4">Sign In</h4>

        <cfif structKeyExists(url, "error") AND len(trim(url.error))>
          <cfoutput>
          <cfswitch expression="#url.error#">
            <cfcase value="windows_unavailable">
              <div class="alert alert-warning" role="alert">
                Windows login is not available on this network. Please sign in with your Cougarnet credentials below.
              </div>
            </cfcase>
            <cfcase value="windows_failed">
              <div class="alert alert-warning" role="alert">
                Windows login did not complete. You may not have access, or your account may not be active. Please sign in with your Cougarnet credentials below.
              </div>
            </cfcase>
            <cfdefaultcase>
              <div class="alert alert-danger" role="alert">
                #encodeForHTML(url.error)#
              </div>
            </cfdefaultcase>
          </cfswitch>
          </cfoutput>
        </cfif>

        <cfif structKeyExists(request, "windowsSSOEnabled") AND request.windowsSSOEnabled>
          <!--- Windows SSO option (revealed after successful probe) --->
          <div id="windows-sso-section" class="mb-4" style="display:none;">
            <a href="auth_windows_start.cfm" class="btn btn-ui-go d-grid w-100">
              <span><i class="bi bi-windows me-2"></i>Login via Windows (SSO)</span>
            </a>
            <div class="text-center mt-2">
              <small class="text-muted">Uses your current Windows / domain session</small>
            </div>
            <hr class="my-3">
          </div>
        </cfif>

        <p class="text-center text-muted small mb-3">Sign in with your Cougarnet credentials</p>

        <form method="post" action="authenticate.cfm" class="needs-validation" novalidate>
          
          <!-- Username -->
          <div class="mb-3">
            <label for="username" class="form-label">COUGARNET</label>
            
            <div class="input-group mb-3">
              <input type="text"
              class="form-control"
              id="username"
              name="username"
              aria-label="username"
              aria-describedby="cougarnet"
              required>
              <span class="input-group-text" id="cougarnet">@cougarnet.uh.edu</span>
            </div>

            <div class="invalid-feedback">
              Please enter your COUGARNET.
            </div>
          </div>

          <!-- Password with Toggle -->
          <div class="mb-3">
            <label for="password" class="form-label">PASSWORD</label>

            <div class="input-group">
              <input
                type="password"
                class="form-control"
                id="password"
                name="password"
                required
              >
              <button
                class="btn btn-ui-cancel text-dark"
                type="button"
                id="togglePassword"
                aria-label="Show password"
              >
                Show
              </button>
              <div class="invalid-feedback">
                Please enter your password.
              </div>
            </div>
          </div>

          <div class="d-grid">
            <button type="submit" class="btn btn-ui-go">
              Login via Cougarnet
            </button>
          </div>

        </form>

        <cfif structKeyExists(request, "windowsSSOEnabled") AND request.windowsSSOEnabled>
          <div class="text-center mt-3">
            <button type="button" class="btn btn-ui-help btn-sm" id="checkWindowsBtn">
              Check Windows Login Availability
            </button>
            <div id="windows-probe-msg" class="small mt-1" style="display:none;"></div>
          </div>
        </cfif>

      </div>
    </div>
  </div>

  <!-- Bootstrap JS (optional, only needed for some components) -->
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>

  <cfoutput><script nonce="#encodeForHTMLAttribute(request.cspNonce ?: '')#"></cfoutput>

    document.getElementById("username").focus();

    // Windows SSO availability probe
    const checkWindowsBtn  = document.getElementById('checkWindowsBtn');
    const windowsSection   = document.getElementById('windows-sso-section');
    const windowsProbeMsg  = document.getElementById('windows-probe-msg');

    if (checkWindowsBtn && windowsSection && windowsProbeMsg) {
      checkWindowsBtn.addEventListener('click', () => {
        checkWindowsBtn.disabled = true;
        checkWindowsBtn.textContent = 'Checking...';
        windowsProbeMsg.style.display = 'none';

        fetch('auth_windows_probe.cfm', { method: 'GET', credentials: 'include' })
          .then(r => {
            if (!r.ok) throw new Error('status:' + r.status);
            return r.json();
          })
          .then(data => {
            if (data.available) {
              windowsSection.style.display = 'block';
              checkWindowsBtn.style.display = 'none';
              windowsProbeMsg.style.display = 'none';
            } else {
              windowsProbeMsg.textContent = 'Windows login is not available on this network.';
              windowsProbeMsg.style.display = 'block';
              checkWindowsBtn.disabled = false;
              checkWindowsBtn.textContent = 'Check Windows Login Availability';
            }
          })
          .catch(err => {
            windowsProbeMsg.textContent = 'Could not check Windows login availability. Please use Cougarnet login.';
            windowsProbeMsg.style.display = 'block';
            checkWindowsBtn.disabled = false;
            checkWindowsBtn.textContent = 'Check Windows Login Availability';
            console.debug('[windows-probe] error:', err && err.message ? err.message : err);
          });
      });
    }

    // Bootstrap client-side validation
    (() => {
      'use strict';

      const forms = document.querySelectorAll('.needs-validation');

      Array.from(forms).forEach(form => {
        form.addEventListener('submit', event => {
          if (!form.checkValidity()) {
            event.preventDefault();
            event.stopPropagation();
          }
          form.classList.add('was-validated');
        }, false);
      });
    })();

    // Show / Hide password toggle
    const passwordInput = document.getElementById('password');
    const toggleBtn = document.getElementById('togglePassword');

    toggleBtn.addEventListener('click', () => {
      const isPassword = passwordInput.type === 'password';
      passwordInput.type = isPassword ? 'text' : 'password';
      toggleBtn.textContent = isPassword ? 'Hide' : 'Show';
    });
  </script>

</body>
</html>