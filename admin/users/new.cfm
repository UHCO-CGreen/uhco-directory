<cfif NOT request.hasPermission("users.edit") OR NOT request.canCreateUsers()>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>
<cfparam name="url.embedded" default="0">
<cfset isEmbedded = val(url.embedded) EQ 1>
<cfset defaultReturnTo = "/admin/users/index.cfm">
<cfset pageCsrfToken = structKeyExists(request, "adminCsrfToken") ? trim(request.adminCsrfToken ?: "") : "">

<cfset content = "
<h1>Quick Add User</h1>

<form class='mt-4' method='POST' action='/admin/users/saveUser.cfm'>
    <input type='hidden' name='embedded' value='#(isEmbedded ? "1" : "0")#'>
    <input type='hidden' name='returnTo' value='#EncodeForHTMLAttribute(defaultReturnTo)#'>
    <input type='hidden' name='_csrf' value='#EncodeForHTMLAttribute(pageCsrfToken)#'>

    <div class='row mb-3'>
        <div class='col-md-4'>
            <label class='form-label'>First Name</label>
            <input class='form-control' name='FirstName' required>
        </div>
        <div class='col-md-4'>
            <label class='form-label'>Middle Name</label>
            <input class='form-control' name='MiddleName'>
        </div>
        <div class='col-md-4'>
            <label class='form-label'>Last Name</label>
            <input class='form-control' name='LastName' required>
        </div>
    </div>

    <div class='row mb-4'>
        <div class='col-md-6'>
            <label class='form-label'>Email</label>
            <input class='form-control' name='EmailPrimary' type='email' required>
        </div>
    </div>

    <button class='btn btn-ui-add' type='submit'>Save User</button>
    <a href='#EncodeForHTMLAttribute(defaultReturnTo)#' class='btn btn-ui-cancel' #(isEmbedded ? "target='_top'" : "")#>Cancel</a>
</form>
" />

<cfif isEmbedded>
    <cfoutput>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Quick Add User</title>
    <link rel="stylesheet" href="/assets/css/admin.css">
</head>
<body class="p-3">
    #content#
</body>
</html>
    </cfoutput>
<cfelse>
    <cfinclude template="/admin/layout.cfm">
</cfif>
