<cfparam name="pageTitle" default="UserReview">
<cfparam name="content" default="">

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><cfoutput>#encodeForHTML(pageTitle)#</cfoutput></title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-sRIl4kxILFvY47J16cr9ZwB07vP4J8+LH7qKQnuqkuIAvNWLzeN8tE5YBujZqJLB" crossorigin="anonymous">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css">
    <style>
        body { background: #f4f6f8; }
        .ur-shell { max-width: 1100px; margin: 0 auto; }
        .ur-header { background: linear-gradient(135deg, #0f3d56, #1b6a8f); color: #fff; border-radius: 1rem; }
        .ur-card { border: 0; border-radius: 1rem; box-shadow: 0 0.5rem 1.25rem rgba(16, 24, 40, 0.08); }
        .row-card { border: 1px solid #dde3ea; border-radius: 0.85rem; padding: 1rem; background: #fff; }
        .mono { font-family: Consolas, 'Courier New', monospace; }
    </style>
</head>
<body>
<div class="container py-4 py-lg-5 ur-shell">
    <div class="ur-header p-4 p-lg-5 mb-4">
        <div class="d-flex justify-content-between align-items-start gap-3 flex-wrap">
            <div>
                <h1 class="h2 mb-2">UserReview</h1>
                <p class="mb-0 opacity-75">Submit profile updates for admin review. Changes stay staged until approved.</p>
            </div>
            <cfif structKeyExists(session, "userReviewUser")>
                <div class="text-end">
                    <div class="small opacity-75">Signed in as</div>
                    <div class="fw-semibold"><cfoutput>#encodeForHTML(session.userReviewUser.displayName ?: session.userReviewUser.username ?: "")#</cfoutput></div>
                    <a href="/UserReview/logout.cfm" class="btn btn-sm btn-light mt-2">Logout</a>
                </div>
            </cfif>
        </div>
    </div>

    <cfoutput>#content#</cfoutput>
</div>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js" integrity="sha384-FKyoEForCGlyvwx9Hj09JcYn3nv7wiPVlz7YYwJrWVcXK/BmnVDxM+D2scQbITxI" crossorigin="anonymous"></script>
</body>
</html>