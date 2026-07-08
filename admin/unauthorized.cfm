<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>
<div class="container-fluid py-4">
	<div class="card border-0 shadow-sm">
		<div class="card-body p-4">
			<h1 class="h4 mb-2"><i class="bi bi-shield-exclamation me-2 text-warning"></i>Access Denied</h1>
			<p class="text-muted mb-4">Your current permission set does not allow access to this page.</p>

			<div class="d-flex flex-wrap gap-2">
				<a href="#request.webRoot#/admin/dashboard.cfm" class="btn btn-ui-go">
					<i class="bi bi-house-door me-1"></i>Go to Dashboard
				</a>
				<a href="#request.webRoot#/admin/logout.cfm" class="btn btn-ui-cancel">
					<i class="bi bi-box-arrow-right me-1"></i>Logout
				</a>
			</div>

			<cfif application.authService.isImpersonating() AND application.authService.isActualSuperAdmin()>
				<hr class="my-4">
				<div class="alert alert-warning mb-3">
					You are currently impersonating a lower-permission role.
				</div>
				<form method="post" action="#request.webRoot#/admin/settings/admin-users/save.cfm" class="mb-0">
					<input type="hidden" name="action" value="clearImpersonation">
					<input type="hidden" name="returnURL" value="/admin/dashboard.cfm">
					<button type="submit" class="btn btn-ui-warning">
						<i class="bi bi-x-octagon me-1"></i>Stop Impersonating
					</button>
				</form>
			</cfif>
		</div>
	</div>
</div>
</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">