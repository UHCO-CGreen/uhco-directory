<cfif NOT request.hasPermission("users.approve_user_review")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfparam name="url.submissionID" default="0">

<cfset userReviewService = createObject("component", "cfc.userReview_service").init()>
<cfset detail = userReviewService.getSubmissionDetail(val(url.submissionID))>

<cfif NOT detail.success>
    <cflocation url="/admin/settings/user-review/?error=#urlEncodedFormat(detail.message)#" addtoken="false">
    <cfabort>
</cfif>

<cfset statusMessage = trim(url.msg ?: "")>
<cfset errorMessage = trim(url.error ?: "")>

<cffunction name="renderReviewValue" access="private" returntype="string" output="false">
    <cfargument name="fieldRow" type="struct" required="true">
    <cfset var value = arguments.fieldRow.PROPOSEDVALUE ?: "">
    <cfif arguments.fieldRow.SECTIONKEY EQ "contact">
        <cfreturn "<pre class='small bg-light border rounded p-3 mb-0'>" & encodeForHTML(value) & "</pre>">
    </cfif>
    <cfif NOT len(trim(value))>
        <cfreturn "<span class='text-muted'>(blank)</span>">
    </cfif>
    <cfreturn encodeForHTML(value)>
</cffunction>

<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-user-review-detail-page">
<nav aria-label="breadcrumb" class="mb-3">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item"><a href="/admin/settings/user-review/">User Review</a></li>
        <li class="breadcrumb-item active" aria-current="page">Submission ## #detail.submission.SUBMISSIONID#</li>
    </ol>
</nav>

<div class="d-flex justify-content-between align-items-start mb-4 gap-3 flex-wrap">
    <div>
        <h1 class="mb-1">UserReview Submission ## #detail.submission.SUBMISSIONID#</h1>
        <p class="text-muted mb-0">#encodeForHTML(trim((detail.submission.FIRSTNAME ?: "") & " " & (detail.submission.LASTNAME ?: "")))# · #encodeForHTML(detail.submission.COUGARNETID ?: "")#</p>
    </div>
    <div class="text-end">
        <div class="small text-muted">Status</div>
        <div><span class="badge text-bg-#detail.submission.STATUS EQ 'pending' ? 'warning' : 'secondary'#">#encodeForHTML(replace(detail.submission.STATUS, "_", " ", "all"))#</span></div>
        <div class="small text-muted mt-2">Submitted #dateTimeFormat(detail.submission.SUBMITTEDAT, "mmm d, yyyy h:nn tt")#</div>
    </div>
</div>

<cfif len(statusMessage)>
    <div class="alert alert-success">#encodeForHTML(statusMessage)#</div>
</cfif>
<cfif len(errorMessage)>
    <div class="alert alert-danger">#encodeForHTML(errorMessage)#</div>
</cfif>

<cfif len(trim(detail.submission.REVIEWNOTE ?: ""))>
    <div class="card shadow-sm mb-4 settings-shell settings-reference-card">
        <div class="card-header"><h5 class="mb-0">Review Notes</h5></div>
        <div class="card-body">
            <pre class="small bg-light border rounded p-3 mb-0">#encodeForHTML(detail.submission.REVIEWNOTE)#</pre>
        </div>
    </div>
</cfif>

<div class="card shadow-sm mb-4 settings-shell settings-summary-card">
    <div class="card-body">
        <form method="post" action="/admin/settings/user-review/resolve.cfm" class="mb-0">
            <input type="hidden" name="submissionID" value="#detail.submission.SUBMISSIONID#">
            <div class="mb-3">
                <label class="form-label">Review Note / Reason</label>
                <textarea name="reviewNote" class="form-control" rows="3" placeholder="Required for discard actions. Notes are appended to the submission."></textarea>
                <div class="form-text">Use this when rejecting any part of a submission. The note stays with the submission history.</div>
            </div>
            <div class="d-flex gap-2 flex-wrap">
                <button type="submit" name="action" value="approveAll" class="btn btn-success"><i class="bi bi-check2-circle me-1"></i>Approve Entire Submission</button>
                <button type="submit" name="action" value="discardAll" class="btn btn-outline-danger" onclick="return requireReviewNote(this.form)"><i class="bi bi-x-circle me-1"></i>Discard Entire Submission</button>
            </div>
        </form>
    </div>
</div>

<div class="card shadow-sm settings-shell">
    <div class="card-header"><h5 class="mb-0">Field Changes</h5></div>
    <div class="card-body p-0">
        <cfif arrayLen(detail.fields)>
            <div class="table-responsive">
                <table class="table table-hover mb-0 align-middle settings-table">
                    <thead>
                        <tr>
                            <th>Section</th>
                            <th>Field</th>
                            <th>Current</th>
                            <th>Proposed</th>
                            <th>Status</th>
                            <th class="text-end">Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        <cfloop array="#detail.fields#" index="fieldRow">
                            <tr>
                                <td class="text-capitalize">#encodeForHTML(fieldRow.SECTIONKEY)#</td>
                                <td>#encodeForHTML(fieldRow.FIELDLABEL)#</td>
                                <td>
                                    <cfif len(trim(fieldRow.CURRENTVALUE ?: ""))>
                                        <cfif fieldRow.SECTIONKEY EQ "contact">
                                            <pre class="small bg-light border rounded p-3 mb-0">#encodeForHTML(fieldRow.CURRENTVALUE)#</pre>
                                        <cfelse>
                                            #encodeForHTML(fieldRow.CURRENTVALUE)#
                                        </cfif>
                                    <cfelse>
                                        <span class="text-muted">(blank)</span>
                                    </cfif>
                                </td>
                                <td>#renderReviewValue(fieldRow)#</td>
                                <td>
                                    <cfif len(trim(fieldRow.RESOLUTION ?: ""))>
                                        <span class="badge text-bg-secondary">#encodeForHTML(fieldRow.RESOLUTION)#</span>
                                    <cfelse>
                                        <span class="badge text-bg-warning">pending</span>
                                    </cfif>
                                </td>
                                <td class="text-end">
                                    <cfif NOT len(trim(fieldRow.RESOLUTION ?: ""))>
                                        <form method="post" action="/admin/settings/user-review/resolve.cfm" class="mb-0 d-flex flex-column align-items-end gap-2">
                                            <input type="hidden" name="submissionID" value="#detail.submission.SUBMISSIONID#">
                                            <input type="hidden" name="submissionFieldID" value="#fieldRow.SUBMISSIONFIELDID#">
                                            <textarea name="reviewNote" class="form-control form-control-sm admin-review-note" rows="2" placeholder="Reason required for discard."></textarea>
                                            <div class="d-flex justify-content-end gap-2">
                                                <button type="submit" name="action" value="approveField" class="btn btn-sm btn-success">Approve</button>
                                                <button type="submit" name="action" value="discardField" class="btn btn-sm btn-outline-danger" onclick="return requireReviewNote(this.form)">Discard</button>
                                            </div>
                                        </form>
                                    </cfif>
                                </td>
                            </tr>
                        </cfloop>
                    </tbody>
                </table>
            </div>
        <cfelse>
            <div class="p-3 text-muted">No field changes were stored for this submission.</div>
        </cfif>
    </div>
</div>

</div>

</cfoutput>

<script>
    function requireReviewNote(form) {
        const noteField = form.querySelector('[name="reviewNote"]');
        if (!noteField || String(noteField.value || '').trim().length > 0) {
            return true;
        }
        alert('A reason for rejection is required.');
        noteField.focus();
        return false;
    }
</script>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">