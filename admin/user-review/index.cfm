<cfif NOT request.hasAnyPermission(["user_review.manage", "users.approve_user_review"] )>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfinclude template="/admin/settings/section-status-config.cfm">
<cfset sectionStatus = getSettingsSectionStatus("user-review")>

<cfset userReviewService = createObject("component", "cfc.userReview_service").init()>
<cfset submissions = userReviewService.listSubmissions()>
<cfset actionMessage = trim(url.msg ?: "")>
<cfset actionError = trim(url.error ?: "")>
<cfset canApproveUserReview = request.hasPermission("users.approve_user_review")>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-user-review-page">
<nav aria-label="breadcrumb" class="mb-3">
    <ol class="breadcrumb">
        <li class="breadcrumb-item active" aria-current="page">User Review</li>
    </ol>
</nav>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h1 class="mb-1"><i class="bi bi-person-lines-fill me-2"></i>User Review</h1>
        <p class="text-muted mb-0">Configure self-service profile review and process staged submissions.</p>
    </div>
    <cfif len(sectionStatus)>
        <span class='badge bg-warning text-dark float-end'>Currently in: #sectionStatus#</span>
    </cfif>
</div>

<cfif len(actionMessage)>
    <div class="alert alert-success">#encodeForHTML(actionMessage)#</div>
</cfif>
<cfif len(actionError)>
    <div class="alert alert-danger">#encodeForHTML(actionError)#</div>
</cfif>


<cfif canApproveUserReview>
<div class="card shadow-sm settings-shell">
    <div class="card-header d-flex justify-content-between align-items-center">
        <h5 class="mb-0">Submissions</h5>
        <span class="badge settings-badge-count">#arrayLen(submissions)#</span>
    </div>
    <div class="card-body p-0">
        <cfif arrayLen(submissions)>
            <div class="table-responsive">
                <table class="table table-hover mb-0 align-middle settings-table">
                    <thead>
                        <tr>
                            <th>User</th>
                            <th>Submitted</th>
                            <th>Status</th>
                            <th>Sections</th>
                            <th class="text-end">Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        <cfloop array="#submissions#" index="submission">
                            <tr>
                                <td>
                                    <div class="fw-semibold">#encodeForHTML(trim((submission.FIRSTNAME ?: "") & " " & (submission.LASTNAME ?: "")))#</div>
                                    <div class="small text-muted">#encodeForHTML(submission.COUGARNETID ?: "")#</div>
                                </td>
                                <td class="small">#dateTimeFormat(submission.SUBMITTEDAT, "mmm d, yyyy h:nn tt")#</td>
                                <td><span class="badge text-bg-#submission.STATUS EQ 'pending' ? 'warning' : 'secondary'#">#encodeForHTML(replace(submission.STATUS, "_", " ", "all"))#</span></td>
                                <td class="small">#encodeForHTML(replace(submission.SECTIONLIST ?: "", ",", ", ", "all"))#</td>
                                <td class="text-end"><a class="btn btn-sm btn-ui-go users-list-action-button users-list-action-button-edit" href="/admin/user-review/review.cfm?submissionID=#submission.SUBMISSIONID#" title="Review Submission" data-bs-toggle="tooltip" data-bs-title="Review Submission" aria-label="Review Submission"><i class="bi bi-pencil-square"></i></a></td>
                            </tr>
                        </cfloop>
                    </tbody>
                </table>
            </div>
        <cfelse>
            <div class="p-3 text-muted">No UserReview submissions yet.</div>
        </cfif>
    </div>
</div>
</cfif>

</div>

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">