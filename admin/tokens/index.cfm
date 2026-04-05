<cfset tokenService = createObject("component", "dir.cfc.token_service").init()>
<cfset tokens = tokenService.getAllTokens()>

<cfset content = "
<h1>API Tokens</h1>
<p class='text-muted'>Tokens grant external applications access to the directory API. The raw token is shown only once at creation.</p>

<div class='mb-3'>
    <a href='/dir/admin/tokens/create.cfm' class='btn btn-primary'><i class='bi bi-plus-lg me-1'></i>New Token</a>
</div>
">

<cfif arrayLen(tokens) EQ 0>
    <cfset content &= "<p class='text-muted'>No tokens created yet.</p>">
<cfelse>
    <cfset content &= "
<div class='table-responsive'>
<table class='table table-striped table-hover align-middle'>
    <thead class='table-dark'>
        <tr>
            <th>Name</th>
            <th>Application</th>
            <th>Scopes</th>
            <th>Allowed IPs</th>
            <th>Expires</th>
            <th>Status</th>
            <th>Last Used</th>
            <th>Created</th>
            <th class='text-end'>Actions</th>
        </tr>
    </thead>
    <tbody>
    ">

    <cfloop from="1" to="#arrayLen(tokens)#" index="i">
        <cfset t = tokens[i]>
        <cfset isActive = t.ISACTIVE EQ 1>
        <cfset isExpired = false>
        <cfif len(trim(t.EXPIRESAT & "")) AND isDate(t.EXPIRESAT)>
            <cfset isExpired = now() GT parseDateTime(t.EXPIRESAT)>
        </cfif>

        <cfset statusBadge = isActive AND !isExpired
            ? "<span class='badge bg-success'>Active</span>"
            : "<span class='badge bg-secondary'>#(isActive ? 'Expired' : 'Revoked')#</span>">

        <cfset expiresDisplay = len(trim(t.EXPIRESAT & "")) ? dateFormat(t.EXPIRESAT, "mmm d, yyyy") : "<span class='text-muted'>Never</span>">
        <cfset lastUsedDisplay = len(trim(t.LASTUSEDAT & "")) ? dateFormat(t.LASTUSEDAT, "mmm d, yyyy") & " " & timeFormat(t.LASTUSEDAT, "h:mm tt") : "<span class='text-muted'>Never</span>">
        <cfset ipDisplay = len(trim(t.ALLOWEDIPS & "")) ? EncodeForHTML(t.ALLOWEDIPS) : "<span class='text-muted'>Any</span>">

        <cfset content &= "
        <tr>
            <td class='fw-semibold'>#EncodeForHTML(t.TOKENNAME)#</td>
            <td>#EncodeForHTML(t.APPNAME)#</td>
            <td><code>#EncodeForHTML(t.SCOPES)#</code></td>
            <td class='small'>#ipDisplay#</td>
            <td class='small'>#expiresDisplay#</td>
            <td>#statusBadge#</td>
            <td class='small'>#lastUsedDisplay#</td>
            <td class='small'>#dateFormat(t.CREATEDAT, 'mmm d, yyyy')#</td>
            <td class='text-end'>
        ">

        <cfif isActive AND !isExpired>
            <cfset content &= "<form method='post' action='/dir/admin/tokens/revokeToken.cfm' class='d-inline' onsubmit=""return confirm('Revoke this token? The application will immediately lose access.')"">
                <input type='hidden' name='tokenID' value='#t.TOKENID#'>
                <button class='btn btn-sm btn-outline-warning'>Revoke</button>
            </form>">
        </cfif>

        <cfset content &= "
                <form method='post' action='/dir/admin/tokens/deleteToken.cfm' class='d-inline ms-1' onsubmit=""return confirm('Permanently delete this token record?')"">
                    <input type='hidden' name='tokenID' value='#t.TOKENID#'>
                    <button class='btn btn-sm btn-outline-danger'>Delete</button>
                </form>
            </td>
        </tr>
        ">
    </cfloop>

    <cfset content &= "
    </tbody>
</table>
</div>
    ">
</cfif>

<cfinclude template="/dir/admin/layout.cfm">
