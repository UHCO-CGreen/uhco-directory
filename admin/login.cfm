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
          <div class="alert alert-danger" role="alert">
            #encodeForHTML(url.error)#
          </div>
          </cfoutput>
        </cfif>

        <form method="post" action="authenticate.cfm" class="needs-validation" novalidate>
          
          <!-- Username -->
          <div class="mb-3">
            <label for="username" class="form-label">COUGARNET ID</label>
            <input
              type="text"
              class="form-control"
              id="username"
              name="username"
              required
            >
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
                class="btn btn-secondary text-dark"
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
            <button type="submit" class="btn btn-primary">
              Login
            </button>
          </div>

        </form>

      </div>
    </div>
  </div>

  <!-- Bootstrap JS (optional, only needed for some components) -->
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>

  <script>

    document.getElementById("username").focus();

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