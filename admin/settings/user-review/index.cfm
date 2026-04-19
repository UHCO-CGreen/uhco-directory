<cfif NOT request.hasAnyPermission(["settings.user_review.manage", "users.approve_user_review"] )>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfset userReviewService = createObject("component", "cfc.userReview_service").init()>
<cfset settings = userReviewService.getSettings()>
<cfset submissions = userReviewService.listSubmissions()>
<cfset actionMessage = trim(url.msg ?: "")>
<cfset actionError = trim(url.error ?: "")>
<cfset canManageUserReviewSettings = request.hasPermission("settings.user_review.manage")>
<cfset canApproveUserReview = request.hasPermission("users.approve_user_review")>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<nav aria-label="breadcrumb" class="mb-3">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active" aria-current="page">User Review</li>
    </ol>
</nav>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h1 class="mb-1"><i class="bi bi-person-lines-fill me-2"></i>User Review</h1>
        <p class="text-muted mb-0">Configure self-service profile review and process staged submissions.</p>
    </div>
</div>

<cfif len(actionMessage)>
    <div class="alert alert-success">#encodeForHTML(actionMessage)#</div>
</cfif>
<cfif len(actionError)>
    <div class="alert alert-danger">#encodeForHTML(actionError)#</div>
</cfif>

<cfif canManageUserReviewSettings>
<div class="card shadow-sm mb-4">
    <div class="card-header"><h5 class="mb-0">Configuration</h5></div>
    <div class="card-body">
        <form method="post" action="/admin/settings/user-review/save.cfm">
            <div class="row g-4">
                <div class="col-lg-4">
                    <label class="form-label fw-bold d-block">Feature State</label>
                    <div class="form-check form-switch">
                        <input class="form-check-input" type="checkbox" id="enabled" name="enabled" value="1" #(settings.enabled ? "checked" : "")#>
                        <label class="form-check-label" for="enabled">Enable UserReview</label>
                    </div>
                </div>
                <div class="col-lg-4">
                    <label class="form-label fw-bold d-block">Eligible Audiences</label>
                    <div class="form-check"><input class="form-check-input" type="checkbox" id="allowFaculty" name="allowFaculty" value="1" #(settings.allowFaculty ? "checked" : "")#><label class="form-check-label" for="allowFaculty">Faculty</label></div>
                    <div class="form-check"><input class="form-check-input" type="checkbox" id="allowStaff" name="allowStaff" value="1" #(settings.allowStaff ? "checked" : "")#><label class="form-check-label" for="allowStaff">Staff</label></div>
                    <div class="form-check"><input class="form-check-input" type="checkbox" id="allowCurrentStudents" name="allowCurrentStudents" value="1" #(settings.allowCurrentStudents ? "checked" : "")#><label class="form-check-label" for="allowCurrentStudents">Current Students</label></div>
                    <div class="form-check"><input class="form-check-input" type="checkbox" id="allowAlumni" name="allowAlumni" value="1" #(settings.allowAlumni ? "checked" : "")#><label class="form-check-label" for="allowAlumni">Alumni</label></div>
                </div>
                <div class="col-lg-4">
                    <label class="form-label fw-bold d-block">Editable Sections</label>
                    <div class="form-check"><input class="form-check-input" type="checkbox" id="sectionGeneral" name="editableSections" value="general" #(arrayFindNoCase(settings.editableSections, "general") ? "checked" : "")#><label class="form-check-label" for="sectionGeneral">General</label></div>
                    <div class="form-check"><input class="form-check-input" type="checkbox" id="sectionContact" name="editableSections" value="contact" #(arrayFindNoCase(settings.editableSections, "contact") ? "checked" : "")#><label class="form-check-label" for="sectionContact">Contact</label></div>
                    <div class="form-check"><input class="form-check-input" type="checkbox" id="sectionBioinfo" name="editableSections" value="bioinfo" #(arrayFindNoCase(settings.editableSections, "bioinfo") ? "checked" : "")#><label class="form-check-label" for="sectionBioinfo">Biographical</label></div>
                </div>
                <div class="col-12">
                    <label for="externalAuthToken" class="form-label fw-bold">External POST Auth Token</label>
                    <input type="text" class="form-control font-monospace" id="externalAuthToken" name="externalAuthToken" value="#encodeForHTMLAttribute(settings.externalAuthToken)#">
                    <div class="form-text">If set, external systems can POST <span class="font-monospace">cougarnetID</span> and this token to <span class="font-monospace">/UserReview/authenticate.cfm</span> for bypass login.</div>
                </div>
            </div>
            <div class="mt-4">
                <button type="submit" class="btn btn-primary"><i class="bi bi-save me-1"></i>Save User Review Settings</button>
            </div>
        </form>
    </div>
</div>
</cfif>

<cfif canApproveUserReview>
<div class="card shadow-sm">
    <div class="card-header d-flex justify-content-between align-items-center">
        <h5 class="mb-0">Submissions</h5>
        <span class="badge bg-secondary">#arrayLen(submissions)#</span>
    </div>
    <div class="card-body p-0">
        <cfif arrayLen(submissions)>
            <div class="table-responsive">
                <table class="table table-hover mb-0 align-middle">
                    <thead class="table-light">
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
                                <td class="text-end"><a class="btn btn-sm btn-outline-primary" href="/admin/settings/user-review/review.cfm?submissionID=#submission.SUBMISSIONID#">Review</a></td>
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

</cfoutput>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">