<cfparam name="pageTitle" default="UserReview">
<cfparam name="content" default="">

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><cfoutput>#encodeForHTML(pageTitle)#</cfoutput></title>
    <link rel="stylesheet" href="/assets/css/userreview.css">
    <link rel="stylesheet" href="/assets/vendor/bootstrap-icons/bootstrap-icons.css">
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