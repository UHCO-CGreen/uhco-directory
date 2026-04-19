<cfif application.userReviewAuthService.isLoggedIn()>
    <cflocation url="/UserReview/index.cfm" addtoken="false">
    <cfabort>
</cfif>

<cfset errorMessage = trim(url.error ?: "")>
<cfset infoMessage = trim(url.msg ?: "")>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="row justify-content-center">
    <div class="col-lg-6">
        <div class="card ur-card">
            <div class="card-body p-4 p-lg-5">
                <h2 class="h4 mb-2">Sign In</h2>
                <p class="text-muted">This sign-in is separate from admin access. Admin roles do not affect how your submission is reviewed here.</p>

                <cfif len(errorMessage)>
                    <div class="alert alert-danger">#encodeForHTML(errorMessage)#</div>
                </cfif>
                <cfif len(infoMessage)>
                    <div class="alert alert-success">#encodeForHTML(infoMessage)#</div>
                </cfif>

                <form method="post" action="/UserReview/authenticate.cfm" class="mt-4">
                    <div class="mb-3">
                        <label for="username" class="form-label">CougarNet Username</label>
                        <input type="text" class="form-control" id="username" name="username" autocomplete="username" required>
                    </div>
                    <div class="mb-4">
                        <label for="password" class="form-label">Password</label>
                        <input type="password" class="form-control" id="password" name="password" autocomplete="current-password" required>
                    </div>
                    <button type="submit" class="btn btn-primary w-100">Continue</button>
                </form>
            </div>
        </div>
    </div>
</div>

</cfoutput>
</cfsavecontent>

<cfset pageTitle = "UserReview Login">
<cfinclude template="/UserReview/layout.cfm">