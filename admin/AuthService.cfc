<cfcomponent displayname="AuthService" output="false">

  <cffunction name="_getLdapAuthGateway" access="private" returntype="any" output="false">
    <cfif NOT structKeyExists(variables, "ldapAuthGateway")>
      <cfset variables.ldapAuthGateway = createObject("component", "cfc.ldapAuthGateway_service").init()>
    </cfif>
    <cfreturn variables.ldapAuthGateway>
  </cffunction>

  <cffunction name="_getAdminSessionsDAO" access="private" returntype="any" output="false">
    <cfif NOT structKeyExists(variables, "adminSessionsDAO")>
      <cfset variables.adminSessionsDAO = createObject("component", "dao.adminSessions_DAO").init()>
    </cfif>
    <cfreturn variables.adminSessionsDAO>
  </cffunction>

  <cffunction name="_getAdminAuthDAO" access="private" returntype="any" output="false">
    <cfif NOT structKeyExists(variables, "adminAuthDAO")>
      <cfset variables.adminAuthDAO = createObject("component", "dao.adminAuth_DAO").init()>
    </cfif>
    <cfreturn variables.adminAuthDAO>
  </cffunction>

  <cffunction name="_getPermissionKeysFromRows" access="private" returntype="array" output="false">
    <cfargument name="permissionRows" type="array" required="true">

    <cfset var permissionKeys = []>
    <cfset var seen = {}>
    <cfset var permissionRow = {}>
    <cfset var permissionKey = "">

    <cfloop array="#arguments.permissionRows#" index="permissionRow">
      <cfif structKeyExists(permissionRow, "PERMISSION_KEY")>
        <cfset permissionKey = trim(permissionRow.PERMISSION_KEY & "")>
        <cfif len(permissionKey) AND NOT structKeyExists(seen, uCase(permissionKey))>
          <cfset seen[uCase(permissionKey)] = true>
          <cfset arrayAppend(permissionKeys, permissionKey)>
        </cfif>
      </cfif>
    </cfloop>

    <cfreturn permissionKeys>
  </cffunction>

  <cffunction name="_loadAuthorizationContext" access="private" returntype="struct" output="false">
    <cfargument name="userID" type="numeric" required="true">

    <cfset var dao = _getAdminAuthDAO()>
    <cfset var roleRows = dao.getRolesForUser(arguments.userID)>
    <cfset var permissionRows = dao.getEffectivePermissionsForUser(arguments.userID)>
    <cfset var roles = []>
    <cfset var roleIDs = []>
    <cfset var roleRow = {}>

    <cfloop array="#roleRows#" index="roleRow">
      <cfif structKeyExists(roleRow, "ROLE_NAME")>
        <cfset arrayAppend(roles, roleRow.ROLE_NAME)>
      </cfif>
      <cfif structKeyExists(roleRow, "ROLE_ID")>
        <cfset arrayAppend(roleIDs, roleRow.ROLE_ID)>
      </cfif>
    </cfloop>

    <cfreturn {
      userID = arguments.userID,
      roles = roles,
      roleIDs = roleIDs,
      permissions = _getPermissionKeysFromRows(permissionRows),
      isSuperAdmin = arrayFindNoCase(roles, "SUPER_ADMIN") GT 0
    }>
  </cffunction>

  <cffunction name="_normalizeSessionUser" access="private" returntype="struct" output="false">
    <cfargument name="user" type="struct" required="true">

    <cfset var normalizedUser = duplicate(arguments.user)>

    <cfif NOT structKeyExists(normalizedUser, "roles") OR NOT isArray(normalizedUser.roles)>
      <cfset normalizedUser.roles = []>
    </cfif>
    <cfif NOT structKeyExists(normalizedUser, "roleIDs") OR NOT isArray(normalizedUser.roleIDs)>
      <cfset normalizedUser.roleIDs = []>
    </cfif>
    <cfif NOT structKeyExists(normalizedUser, "permissions") OR NOT isArray(normalizedUser.permissions)>
      <cfset normalizedUser.permissions = []>
    </cfif>
    <cfif NOT structKeyExists(normalizedUser, "isSuperAdmin")>
      <cfset normalizedUser.isSuperAdmin = (arrayFindNoCase(normalizedUser.roles, "SUPER_ADMIN") GT 0)>
    </cfif>

    <cfif NOT structKeyExists(normalizedUser, "actualRoles") OR NOT isArray(normalizedUser.actualRoles)>
      <cfset normalizedUser.actualRoles = duplicate(normalizedUser.roles)>
    </cfif>
    <cfif NOT structKeyExists(normalizedUser, "actualRoleIDs") OR NOT isArray(normalizedUser.actualRoleIDs)>
      <cfset normalizedUser.actualRoleIDs = duplicate(normalizedUser.roleIDs)>
    </cfif>
    <cfif NOT structKeyExists(normalizedUser, "actualPermissions") OR NOT isArray(normalizedUser.actualPermissions)>
      <cfset normalizedUser.actualPermissions = duplicate(normalizedUser.permissions)>
    </cfif>
    <cfif NOT structKeyExists(normalizedUser, "actualIsSuperAdmin")>
      <cfset normalizedUser.actualIsSuperAdmin = (arrayFindNoCase(normalizedUser.actualRoles, "SUPER_ADMIN") GT 0)>
    </cfif>
    <cfif NOT structKeyExists(normalizedUser, "impersonation") OR NOT isStruct(normalizedUser.impersonation)>
      <cfset normalizedUser.impersonation = {}>
    </cfif>

    <cfreturn normalizedUser>
  </cffunction>

  <cffunction name="_applyEffectiveAuthorization" access="private" returntype="void" output="false">
    <cfargument name="roles" type="array" required="true">
    <cfargument name="roleIDs" type="array" required="true">
    <cfargument name="permissions" type="array" required="true">
    <cfargument name="isSuperAdmin" type="boolean" required="true">

    <cfset session.user.roles = duplicate(arguments.roles)>
    <cfset session.user.roleIDs = duplicate(arguments.roleIDs)>
    <cfset session.user.permissions = duplicate(arguments.permissions)>
    <cfset session.user.isSuperAdmin = arguments.isSuperAdmin>
  </cffunction>

  <cffunction
    name="authenticate"
    access="public"
    returntype="struct"
    output="false"
  >
    <cfargument name="username" type="string" required="true">
    <cfargument name="password" type="string" required="true">

    <cfset var result = {
      success = false,
      message = "",
      user    = {}
    }>
    <cfset var ldapGateway = _getLdapAuthGateway()>
    <cfset var GetUserInfo = "">

    <cftry>
      <cfset GetUserInfo = ldapGateway.queryUserByCredentials(
        username = arguments.username,
        password = arguments.password,
        attributes = "displayName,memberOf,sAMAccountName,mail,telephoneNumber,accountExpires,userAccountControl,department,title,initials",
        allowedGroupDNs = ldapGateway.getAdminAllowedGroupDNs()
      )>
  
      <!--- Authorization check --->
      <cfif GetUserInfo.recordCount EQ 0>
        <cfset result.message = "User not authorized">
        <cfreturn result>
      </cfif>

      <!--- Disabled account --->
      <cfif bitAnd(GetUserInfo.userAccountControl, 2)>
        <cfset result.message = "Account disabled">
        <cfreturn result>
      </cfif>

      <!--- Account expired --->
      <cfif GetUserInfo.accountExpires NEQ 0
         AND GetUserInfo.accountExpires LT
           dateDiff("s", createDate(1601,1,1), now())>
        <cfset result.message = "Account expired">
        <cfreturn result>
      </cfif>

      <!--- Verify against admin access membership --->
      <cfset var adminAuthDAO = _getAdminAuthDAO()>
      <cfset var accessUser = {}>
      <cfset var activeDatasource = structKeyExists(request, "datasource") ? request.datasource : "(request.datasource not set)">
      <cfset var activeHost = structKeyExists(cgi, "server_name") ? cgi.server_name : "(unknown host)">
      <cftry>
        <cfset accessUser = adminAuthDAO.getUserByCougarnet(lCase(trim(GetUserInfo.sAMAccountName & "")))>
        <cfcatch type="any">
          <cflog
            file="auth-login"
            type="error"
            text="ACCESS CHECK DB ERROR | user=#arguments.username# | ds=#activeDatasource# | host=#activeHost# | #cfcatch.message# | #cfcatch.detail#"
          >
          <cfset result.message = "Authentication service is temporarily unavailable. Please try again shortly.">
          <cfreturn result>
        </cfcatch>
      </cftry>
      <cfif NOT structCount(accessUser) OR NOT val(accessUser.IS_ACTIVE)>
        <cfset result.message = "User not authorized - Not found in access list">
        <cfreturn result>
      </cfif>

      <cfset var authorization = _loadAuthorizationContext(val(accessUser.USER_ID))>

      <cfif arrayLen(authorization.roles) EQ 0>
        <cfset result.message = "User not authorized - No access role assigned">
        <cfreturn result>
      </cfif>



      <!--- Success --->
      <cfset result.success = true>
      <cfset result.user = {
        adminUserID  = val(accessUser.USER_ID),
        username    = GetUserInfo.sAMAccountName,
        displayName = GetUserInfo.displayName,
        email       = GetUserInfo.mail,
        department  = GetUserInfo.department,
        title       = GetUserInfo.title,
        phone       = GetUserInfo.telephoneNumber,
        authType    = "ldap",
        loginAt     = now(),
        roles       = authorization.roles,
        roleIDs     = authorization.roleIDs,
        permissions = authorization.permissions,
        actualRoles = authorization.roles,
        actualRoleIDs = authorization.roleIDs,
        actualPermissions = authorization.permissions,
        actualIsSuperAdmin = authorization.isSuperAdmin,
        isSuperAdmin = authorization.isSuperAdmin
      }>

      <cfreturn result>

      <cfcatch type="any">
        <cflog
          file="auth-login"
          type="error"
          text="AUTH ERROR | user=#arguments.username# | #cfcatch.message# | #cfcatch.detail#"
        >
        <cfif cfcatch.message CONTAINS "error code 49">
          <cfif cfcatch.message CONTAINS "52e">
            <cfset result.message = "Error 52e: Invalid credentials. Please check your username or password and try again.">
          <cfelseif cfcatch.message CONTAINS "525">
            <cfset result.message = "Error 525: User not found. Please check your username and try again.">
          <cfelseif cfcatch.message CONTAINS "530">
            <cfset result.message = "Error 530: Not permitted to log on at this time. Please contact your IT admin.">
          <cfelseif cfcatch.message CONTAINS "532">
            <cfset result.message = "Error 532: Password expired. Please change your password before attempting to log in again.">
          <cfelseif cfcatch.message CONTAINS "533">
            <cfset result.message = "Error 533: Account disabled. Please contact your IT admin.">
          <cfelseif cfcatch.message CONTAINS "701">
            <cfset result.message = "Error 701: Account expired. Please contact your IT admin.">
          <cfelseif cfcatch.message CONTAINS "773">
            <cfset result.message = "Error 773: You must reset your password before logging in.">
          <cfelse>
            <cfset result.message = "Login failed (code 49). Please try again.">
          </cfif>
        <cfelse>
          <cfset result.message = "Authentication service is temporarily unavailable. Please try again shortly.">
        </cfif>
        <cfreturn result>
      </cfcatch>

    </cftry>

  </cffunction>

  <cffunction
    name="authenticateTrustedLaunch"
    access="public"
    returntype="struct"
    output="false"
  >
    <cfargument name="username" type="string" required="true">
    <cfargument name="canonicalUserID" type="numeric" required="false" default="0">
    <cfargument name="displayName" type="string" required="false" default="">
    <cfargument name="email" type="string" required="false" default="">
    <cfargument name="department" type="string" required="false" default="">
    <cfargument name="title" type="string" required="false" default="">
    <cfargument name="authType" type="string" required="false" default="myuhco-token">

    <cfset var result = {
      success = false,
      message = "",
      user = {}
    }>
    <cfset var adminAuthDAO = _getAdminAuthDAO()>
    <cfset var normalizedUsername = lCase(trim(arguments.username & ""))>
    <cfset var accessUser = {}>
    <cfset var authorization = {}>
    <cfset var effectiveDisplayName = trim(arguments.displayName & "")>

    <cfif NOT len(normalizedUsername)>
      <cfset result.message = "Trusted launch username is required.">
      <cfreturn result>
    </cfif>

    <cftry>
      <cfset accessUser = adminAuthDAO.getUserByCougarnet(normalizedUsername)>

      <cfif NOT structCount(accessUser) OR NOT val(accessUser.IS_ACTIVE)>
        <cfset result.message = "User not authorized - Not found in access list">
        <cfreturn result>
      </cfif>

      <cfset authorization = _loadAuthorizationContext(val(accessUser.USER_ID))>

      <cfif arrayLen(authorization.roles) EQ 0>
        <cfset result.message = "User not authorized - No access role assigned">
        <cfreturn result>
      </cfif>

      <cfif NOT len(effectiveDisplayName)>
        <cfset effectiveDisplayName = normalizedUsername>
      </cfif>

      <cfset result.success = true>
      <cfset result.user = {
        adminUserID = val(accessUser.USER_ID),
        userID = int(val(arguments.canonicalUserID)),
        username = normalizedUsername,
        displayName = effectiveDisplayName,
        email = trim(arguments.email & ""),
        department = trim(arguments.department & ""),
        title = trim(arguments.title & ""),
        authType = trim(arguments.authType & ""),
        loginAt = now(),
        roles = authorization.roles,
        roleIDs = authorization.roleIDs,
        permissions = authorization.permissions,
        actualRoles = authorization.roles,
        actualRoleIDs = authorization.roleIDs,
        actualPermissions = authorization.permissions,
        actualIsSuperAdmin = authorization.isSuperAdmin,
        isSuperAdmin = authorization.isSuperAdmin
      }>

      <cfif structKeyExists(application, "authAuditService") AND isObject(application.authAuditService)>
        <cfset application.authAuditService.log(
          source      = "admin",
          eventType   = "TRUSTED_LAUNCH",
          adminUserID = val(accessUser.USER_ID),
          username    = normalizedUsername,
          ipAddress   = left(trim(cgi.remote_addr & ""), 50),
          details     = "authType=#trim(arguments.authType & "")#"
        )>
      </cfif>

      <cfreturn result>

      <cfcatch type="any">
        <cflog
          file="auth-login"
          type="error"
          text="TRUSTED LAUNCH AUTH ERROR | user=#normalizedUsername# | #cfcatch.message# | #cfcatch.detail#"
        >
        <cfset result.message = "Trusted launch authentication failed.">
        <cfreturn result>
      </cfcatch>
    </cftry>
  </cffunction>

    <cffunction
        name="isLoggedIn"
        access="public"
        returntype="boolean"
        output="false"
        >
        <cfreturn structKeyExists(session, "user")>
    </cffunction>

    <cffunction name="hasRole" access="public" returntype="boolean" output="false">
      <cfargument name="role" type="string" required="true">

      <cfif structKeyExists(session, "user") AND session.user.isSuperAdmin>
        <cfreturn true>
      </cfif>

      <cfif NOT structKeyExists(session, "user")>
        <cfreturn false>
      </cfif>

      <cfreturn arrayFindNoCase(session.user.roles, arguments.role) GT 0>
    </cffunction>

    <cffunction name="hasAnyRole" access="public" returntype="boolean" output="false">
      <cfargument name="roles" type="array" required="true">

      <cfif structKeyExists(session, "user") AND session.user.isSuperAdmin>
        <cfreturn true>
      </cfif>

      <cfif NOT structKeyExists(session, "user")>
        <cfreturn false>
      </cfif>

      <cfloop array="#arguments.roles#" index="r">
        <cfif arrayFindNoCase(session.user.roles, r) GT 0>
          <cfreturn true>
        </cfif>
      </cfloop>

      <cfreturn false>
    </cffunction>

    <cffunction name="hasPermission" access="public" returntype="boolean" output="false">
      <cfargument name="permission" type="string" required="true">

      <cfif structKeyExists(session, "user") AND structKeyExists(session.user, "isSuperAdmin") AND session.user.isSuperAdmin>
        <cfreturn true>
      </cfif>

      <cfif NOT structKeyExists(session, "user")>
        <cfreturn false>
      </cfif>

      <cfif NOT structKeyExists(session.user, "permissions") OR NOT isArray(session.user.permissions)>
        <cfreturn false>
      </cfif>

      <cfreturn arrayFindNoCase(session.user.permissions, arguments.permission) GT 0>
    </cffunction>

    <cffunction name="hasAnyPermission" access="public" returntype="boolean" output="false">
      <cfargument name="permissions" type="array" required="true">

      <cfif structKeyExists(session, "user") AND structKeyExists(session.user, "isSuperAdmin") AND session.user.isSuperAdmin>
        <cfreturn true>
      </cfif>

      <cfif NOT structKeyExists(session, "user")>
        <cfreturn false>
      </cfif>

      <cfif NOT structKeyExists(session.user, "permissions") OR NOT isArray(session.user.permissions)>
        <cfreturn false>
      </cfif>

      <cfloop array="#arguments.permissions#" index="permissionKey">
        <cfif arrayFindNoCase(session.user.permissions, permissionKey) GT 0>
          <cfreturn true>
        </cfif>
      </cfloop>

      <cfreturn false>
    </cffunction>

    <cffunction name="getEffectivePermissions" access="public" returntype="array" output="false">
      <cfif NOT structKeyExists(session, "user")>
        <cfreturn []>
      </cfif>

      <cfif structKeyExists(session.user, "permissions") AND isArray(session.user.permissions)>
        <cfreturn duplicate(session.user.permissions)>
      </cfif>

      <cfreturn []>
    </cffunction>

    <cffunction name="isActualSuperAdmin" access="public" returntype="boolean" output="false">
      <cfif NOT structKeyExists(session, "user")>
        <cfreturn false>
      </cfif>

      <cfif structKeyExists(session.user, "actualIsSuperAdmin")>
        <cfreturn session.user.actualIsSuperAdmin>
      </cfif>

      <cfif structKeyExists(session.user, "isSuperAdmin")>
        <cfreturn session.user.isSuperAdmin>
      </cfif>

      <cfreturn false>
    </cffunction>

    <cffunction name="isImpersonating" access="public" returntype="boolean" output="false">
      <cfif NOT structKeyExists(session, "user")>
        <cfreturn false>
      </cfif>

      <cfreturn structKeyExists(session.user, "impersonation")
        AND isStruct(session.user.impersonation)
        AND structKeyExists(session.user.impersonation, "active")
        AND session.user.impersonation.active>
    </cffunction>

    <cffunction name="getImpersonationState" access="public" returntype="struct" output="false">
      <cfif isImpersonating()>
        <cfreturn duplicate(session.user.impersonation)>
      </cfif>
      <cfreturn {}>
    </cffunction>

    <cffunction name="startRoleImpersonation" access="public" returntype="struct" output="false">
      <cfargument name="roleID" type="numeric" required="true">

      <cfset var result = { success = false, message = "" }>
      <cfset var dao = _getAdminAuthDAO()>
      <cfset var role = {}>
      <cfset var permissionRows = []>
      <cfset var permissionKeys = []>

      <cfif NOT isActualSuperAdmin()>
        <cfset result.message = "Only an actual SUPER_ADMIN can start impersonation.">
        <cfreturn result>
      </cfif>

      <cfif NOT structKeyExists(session, "user")>
        <cfset result.message = "No active session found.">
        <cfreturn result>
      </cfif>

      <cfset role = dao.getRoleByID(arguments.roleID)>
      <cfif NOT structCount(role)>
        <cfset result.message = "Role not found.">
        <cfreturn result>
      </cfif>

      <cfif role.ROLE_NAME EQ "SUPER_ADMIN">
        <cfset result.message = "Cannot impersonate the SUPER_ADMIN role.">
        <cfreturn result>
      </cfif>

      <cfset permissionRows = dao.getPermissionsForRole(arguments.roleID)>
      <cfset permissionKeys = _getPermissionKeysFromRows(permissionRows)>
      <cfset session.user = _normalizeSessionUser(session.user)>
      <cfset session.user.impersonation = {
        active = true,
        type = "role",
        label = "Role: " & role.ROLE_NAME,
        roleIDs = [role.ROLE_ID],
        roles = [role.ROLE_NAME],
        permissions = permissionKeys,
        startedAt = now()
      }>
      <cfset _applyEffectiveAuthorization([role.ROLE_NAME], [role.ROLE_ID], permissionKeys, false)>

      <cfset result.success = true>
      <cfset result.message = "Now impersonating role '" & role.ROLE_NAME & "'.">
      <cfif structKeyExists(application, "authAuditService") AND isObject(application.authAuditService) AND structKeyExists(session, "user") AND val(session.user.adminUserID ?: 0)>
        <cfset application.authAuditService.log(
          source      = "admin",
          eventType   = "IMPERSONATE_START",
          adminUserID = session.user.adminUserID,
          username    = session.user.username ?: "",
          ipAddress   = left(trim(cgi.remote_addr & ""), 50),
          details     = "type=role|roleID=#arguments.roleID#|label=#role.ROLE_NAME#"
        )>
      </cfif>
      <cfreturn result>
    </cffunction>

    <cffunction name="startPermissionImpersonation" access="public" returntype="struct" output="false">
      <cfargument name="permissionIDs" type="array" required="true">

      <cfset var result = { success = false, message = "" }>
      <cfset var dao = _getAdminAuthDAO()>
      <cfset var allPermissions = []>
      <cfset var permissionLookup = {}>
      <cfset var permissionRow = {}>
      <cfset var selectedPermissionKeys = []>
      <cfset var seen = {}>
      <cfset var permissionID = 0>
      <cfset var selectedCount = 0>

      <cfif NOT isActualSuperAdmin()>
        <cfset result.message = "Only an actual SUPER_ADMIN can start impersonation.">
        <cfreturn result>
      </cfif>

      <cfif NOT structKeyExists(session, "user")>
        <cfset result.message = "No active session found.">
        <cfreturn result>
      </cfif>

      <cfset allPermissions = dao.getAllPermissions()>
      <cfloop array="#allPermissions#" index="permissionRow">
        <cfset permissionLookup[toString(permissionRow.PERMISSION_ID)] = permissionRow.PERMISSION_KEY>
      </cfloop>

      <cfloop array="#arguments.permissionIDs#" index="permissionID">
        <cfif isNumeric(permissionID) AND val(permissionID) GT 0 AND structKeyExists(permissionLookup, toString(val(permissionID)))>
          <cfif NOT structKeyExists(seen, permissionLookup[toString(val(permissionID))])>
            <cfset seen[permissionLookup[toString(val(permissionID))]] = true>
            <cfset arrayAppend(selectedPermissionKeys, permissionLookup[toString(val(permissionID))])>
          </cfif>
        </cfif>
      </cfloop>

      <cfset selectedCount = arrayLen(selectedPermissionKeys)>
      <cfif selectedCount EQ 0>
        <cfset result.message = "Select at least one permission to impersonate.">
        <cfreturn result>
      </cfif>

      <cfset session.user = _normalizeSessionUser(session.user)>
      <cfset session.user.impersonation = {
        active = true,
        type = "permissions",
        label = "Custom permissions (" & selectedCount & ")",
        roleIDs = [],
        roles = [],
        permissions = duplicate(selectedPermissionKeys),
        startedAt = now()
      }>
      <cfset _applyEffectiveAuthorization([], [], selectedPermissionKeys, false)>

      <cfset result.success = true>
      <cfset result.message = "Now impersonating custom permissions.">
      <cfif structKeyExists(application, "authAuditService") AND isObject(application.authAuditService) AND structKeyExists(session, "user") AND val(session.user.adminUserID ?: 0)>
        <cfset application.authAuditService.log(
          source      = "admin",
          eventType   = "IMPERSONATE_START",
          adminUserID = session.user.adminUserID,
          username    = session.user.username ?: "",
          ipAddress   = left(trim(cgi.remote_addr & ""), 50),
          details     = "type=permissions|count=#selectedCount#"
        )>
      </cfif>
      <cfreturn result>
    </cffunction>

    <cffunction name="startUserImpersonation" access="public" returntype="struct" output="false">
      <cfargument name="userID" type="numeric" required="true">

      <cfset var result  = { success = false, message = "" }>
      <cfset var dao     = _getAdminAuthDAO()>
      <cfset var ctx     = {}>
      <cfset var roleStr = "">
      <cfset var labelStr = "">
      <cfset var targetUser = {}>

      <cfif NOT isActualSuperAdmin()>
        <cfset result.message = "Only an actual SUPER_ADMIN can start impersonation.">
        <cfreturn result>
      </cfif>

      <cfif NOT structKeyExists(session, "user")>
        <cfset result.message = "No active session found.">
        <cfreturn result>
      </cfif>

      <!--- Prevent impersonating yourself or another super admin --->
      <cfset ctx = _loadAuthorizationContext(arguments.userID)>
      <cfif NOT structCount(ctx) OR NOT structKeyExists(ctx, "userID")>
        <cfset result.message = "User not found.">
        <cfreturn result>
      </cfif>
      <cfif ctx.isSuperAdmin>
        <cfset result.message = "Cannot impersonate a SUPER_ADMIN user.">
        <cfreturn result>
      </cfif>
      <cfif val(arguments.userID) EQ val(session.user.adminUserID ?: 0)>
        <cfset result.message = "Cannot impersonate yourself.">
        <cfreturn result>
      </cfif>

      <!--- Fetch cougarnet for a readable label --->
      <cfset targetUser = dao.getUserByID(arguments.userID)>
      <cfset roleStr = arrayLen(ctx.roles) ? arrayToList(ctx.roles, ", ") : "No roles">
      <cfset labelStr = "User: " & (structKeyExists(targetUser, "COUGARNET") ? targetUser.COUGARNET : arguments.userID) & " (" & roleStr & ")">

      <cfset session.user = _normalizeSessionUser(session.user)>
      <cfset session.user.impersonation = {
        active      = true,
        type        = "user",
        label       = labelStr,
        roleIDs     = ctx.roleIDs,
        roles       = ctx.roles,
        permissions = ctx.permissions,
        startedAt   = now()
      }>
      <cfset _applyEffectiveAuthorization(ctx.roles, ctx.roleIDs, ctx.permissions, false)>

      <cfset result.success = true>
      <cfset result.message = "Now impersonating " & labelStr & ".">
      <cfif structKeyExists(application, "authAuditService") AND isObject(application.authAuditService) AND structKeyExists(session, "user") AND val(session.user.adminUserID ?: 0)>
        <cfset application.authAuditService.log(
          source      = "admin",
          eventType   = "IMPERSONATE_START",
          adminUserID = session.user.adminUserID,
          username    = session.user.username ?: "",
          ipAddress   = left(trim(cgi.remote_addr & ""), 50),
          details     = "type=user|targetUserID=#arguments.userID#|label=#labelStr#"
        )>
      </cfif>
      <cfreturn result>
    </cffunction>

    <cffunction name="startImpersonation" access="public" returntype="struct" output="false">
      <cfargument name="roleID"                  type="numeric" required="true">
      <cfargument name="additionalPermissionIDs" type="array"   required="false" default="#[]#">

      <cfset var result             = { success = false, message = "" }>
      <cfset var dao                = _getAdminAuthDAO()>
      <cfset var role               = {}>
      <cfset var rolePermissionRows = []>
      <cfset var rolePermissionKeys = []>
      <cfset var allPermissions     = []>
      <cfset var permissionLookup   = {}>
      <cfset var additionalKeys     = []>
      <cfset var mergedKeys         = []>
      <cfset var mergedSeen         = {}>
      <cfset var additionalCount    = 0>
      <cfset var labelStr           = "">
      <cfset var permID             = 0>
      <cfset var permKey            = "">
      <cfset var permRow            = {}>

      <cfif NOT isActualSuperAdmin()>
        <cfset result.message = "Only an actual SUPER_ADMIN can start impersonation.">
        <cfreturn result>
      </cfif>

      <cfif NOT structKeyExists(session, "user")>
        <cfset result.message = "No active session found.">
        <cfreturn result>
      </cfif>

      <cfset role = dao.getRoleByID(arguments.roleID)>
      <cfif NOT structCount(role)>
        <cfset result.message = "Role not found.">
        <cfreturn result>
      </cfif>

      <cfif role.ROLE_NAME EQ "SUPER_ADMIN">
        <cfset result.message = "Cannot impersonate the SUPER_ADMIN role.">
        <cfreturn result>
      </cfif>

      <!--- Build role default permission key set --->
      <cfset rolePermissionRows = dao.getPermissionsForRole(arguments.roleID)>
      <cfset rolePermissionKeys = _getPermissionKeysFromRows(rolePermissionRows)>

      <!--- Seed merged set with role defaults --->
      <cfloop array="#rolePermissionKeys#" index="permKey">
        <cfset mergedSeen[permKey] = true>
        <cfset arrayAppend(mergedKeys, permKey)>
      </cfloop>

      <!--- Resolve additional permission IDs to keys --->
      <cfif arrayLen(arguments.additionalPermissionIDs)>
        <cfset allPermissions = dao.getAllPermissions()>
        <cfloop array="#allPermissions#" index="permRow">
          <cfset permissionLookup[toString(permRow.PERMISSION_ID)] = permRow.PERMISSION_KEY>
        </cfloop>

        <cfloop array="#arguments.additionalPermissionIDs#" index="permID">
          <cfif isNumeric(permID) AND val(permID) GT 0 AND structKeyExists(permissionLookup, toString(val(permID)))>
            <cfset permKey = permissionLookup[toString(val(permID))]>
            <cfif NOT structKeyExists(mergedSeen, permKey)>
              <cfset mergedSeen[permKey] = true>
              <cfset arrayAppend(mergedKeys, permKey)>
              <cfset additionalCount = additionalCount + 1>
            </cfif>
          </cfif>
        </cfloop>
      </cfif>

      <!--- Build label --->
      <cfif additionalCount GT 0>
        <cfset labelStr = "Role: " & role.ROLE_NAME & " (+" & additionalCount & " additional)">
      <cfelse>
        <cfset labelStr = "Role: " & role.ROLE_NAME>
      </cfif>

      <cfset session.user = _normalizeSessionUser(session.user)>
      <cfset session.user.impersonation = {
        active      = true,
        type        = "role",
        label       = labelStr,
        roleIDs     = [role.ROLE_ID],
        roles       = [role.ROLE_NAME],
        permissions = duplicate(mergedKeys),
        startedAt   = now()
      }>
      <cfset _applyEffectiveAuthorization([role.ROLE_NAME], [role.ROLE_ID], mergedKeys, false)>

      <cfset result.success = true>
      <cfset result.message = "Now impersonating " & labelStr & ".">
      <cfif structKeyExists(application, "authAuditService") AND isObject(application.authAuditService) AND structKeyExists(session, "user") AND val(session.user.adminUserID ?: 0)>
        <cfset application.authAuditService.log(
          source      = "admin",
          eventType   = "IMPERSONATE_START",
          adminUserID = session.user.adminUserID,
          username    = session.user.username ?: "",
          ipAddress   = left(trim(cgi.remote_addr & ""), 50),
          details     = "type=role+extra|roleID=#arguments.roleID#|label=#labelStr#"
        )>
      </cfif>
      <cfreturn result>
    </cffunction>

    <cffunction name="clearImpersonation" access="public" returntype="boolean" output="false">
      <cfif NOT structKeyExists(session, "user")>
        <cfreturn false>
      </cfif>

      <cfset session.user = _normalizeSessionUser(session.user)>
      <cfset session.user.impersonation = {}>
      <cfset _applyEffectiveAuthorization(
        session.user.actualRoles,
        session.user.actualRoleIDs,
        session.user.actualPermissions,
        session.user.actualIsSuperAdmin
      )>

      <cfif structKeyExists(application, "authAuditService") AND isObject(application.authAuditService) AND val(session.user.adminUserID ?: 0)>
        <cfset application.authAuditService.log(
          source      = "admin",
          eventType   = "IMPERSONATE_END",
          adminUserID = session.user.adminUserID,
          username    = session.user.username ?: "",
          ipAddress   = left(trim(cgi.remote_addr & ""), 50)
        )>
      </cfif>

      <cfreturn true>
    </cffunction>

    <cffunction name="reloadAuthorization" access="public" returntype="boolean" output="false">
      <cfargument name="userID" type="numeric" required="false" default="0">
      <cfargument name="cougarnet" type="string" required="false" default="">

      <cfset var dao = _getAdminAuthDAO()>
      <cfset var resolvedUserID = val(arguments.userID)>
      <cfset var userRecord = {}>
      <cfset var authorization = {}>

      <cfif NOT structKeyExists(session, "user")>
        <cfreturn false>
      </cfif>

      <cfif resolvedUserID LTE 0>
        <cfif len(trim(arguments.cougarnet))>
          <cfset userRecord = dao.getUserByCougarnet(lCase(trim(arguments.cougarnet)))>
        <cfelseif structKeyExists(session.user, "adminUserID") AND val(session.user.adminUserID) GT 0>
          <cfset userRecord = dao.getUserByID(val(session.user.adminUserID))>
        <cfelseif structKeyExists(session.user, "username")>
          <cfset userRecord = dao.getUserByCougarnet(lCase(trim(session.user.username & "")))>
        </cfif>

        <cfif structCount(userRecord)>
          <cfset resolvedUserID = val(userRecord.USER_ID)>
        </cfif>
      </cfif>

      <cfif resolvedUserID LTE 0>
        <cfreturn false>
      </cfif>

      <cfset authorization = _loadAuthorizationContext(resolvedUserID)>
      <cfset session.user = _normalizeSessionUser(session.user)>
      <cfset session.user.adminUserID = resolvedUserID>
      <cfset session.user.actualRoles = authorization.roles>
      <cfset session.user.actualRoleIDs = authorization.roleIDs>
      <cfset session.user.actualPermissions = authorization.permissions>
      <cfset session.user.actualIsSuperAdmin = authorization.isSuperAdmin>

      <cfif isImpersonating()>
        <cfset session.user.impersonation.active = true>
      <cfelse>
        <cfset _applyEffectiveAuthorization(authorization.roles, authorization.roleIDs, authorization.permissions, authorization.isSuperAdmin)>
      </cfif>

      <cfreturn true>
    </cffunction>

    <cffunction
        name="createSession"
        access="public"
        returntype="void"
        output="false"
        >
        <cfargument name="user" type="struct" required="true">

        <cfset sessionRotate()>
        <cfif structKeyExists(session, "adminCsrfToken")>
          <cfset structDelete(session, "adminCsrfToken", false)>
        </cfif>
        <cfset session.user = _normalizeSessionUser(arguments.user)>
        <cftry>
          <cfset _getAdminSessionsDAO().createSession(
            adminUserID = val(session.user.adminUserID ?: 0),
            ipAddress   = left(trim(cgi.remote_addr & ""), 50),
            userAgent   = left(trim(cgi.http_user_agent & ""), 500)
          )>
        <cfcatch type="any"></cfcatch>
        </cftry>
    </cffunction>

    <cffunction
        name="logout"
        access="public"
        returntype="void"
        output="false"
        >
        <!--- Close DB session rows before clearing the in-memory session --->
        <cfif structKeyExists(session, "user") AND val(session.user.adminUserID ?: 0)>
            <cftry>
                <cfset _getAdminSessionsDAO().closeSessionsForUser(val(session.user.adminUserID))>
            <cfcatch type="any"></cfcatch>
            </cftry>
        </cfif>

        <!--- Clear user session data --->
        <cfif structKeyExists(session, "user")>
            <cfset structDelete(session, "user")>
        </cfif>

        <cfset sessionInvalidate()>
        </cffunction>

  <!--- ═══════════════════════════════════════════════════════════
        Windows Integrated Authentication
        ═══════════════════════════════════════════════════════════ --->

  <cffunction name="_normalizeWindowsIdentity" access="private" returntype="string" output="false">
    <cfargument name="remoteUser" type="string" required="true">
    <!---
      Accepts DOMAIN\username or plain username.
      Returns lowercase username, or empty string if input is malformed/empty.
    --->
    <cfset var raw = trim(arguments.remoteUser)>
    <cfset var username = "">

    <cfif NOT len(raw)>
      <cfreturn "">
    </cfif>

    <!--- Strip domain prefix if present --->
    <cfif raw CONTAINS "\">
      <cfset username = listLast(raw, "\")>
    <cfelse>
      <cfset username = raw>
    </cfif>

    <cfset username = lCase(trim(username))>

    <!--- Reject if nothing usable remains --->
    <cfif NOT len(username) OR NOT reFind("^[a-z0-9._\-]+$", username)>
      <cfreturn "">
    </cfif>

    <cfreturn username>
  </cffunction>

  <cffunction name="authenticateWindowsIntegrated" access="public" returntype="struct" output="false">
    <cfargument name="remoteUser" type="string" required="true">
    <!---
      Authenticates a user whose identity was provided by IIS Windows Authentication.
      Returns the same {success, message, user} contract as authenticate().
      No password is collected or validated.
    --->

    <cfset var result = {
      success = false,
      message = "",
      user    = {}
    }>

    <cfset var username      = _normalizeWindowsIdentity(arguments.remoteUser)>
    <cfset var dao           = _getAdminAuthDAO()>
    <cfset var accessUser    = {}>
    <cfset var authorization = {}>

    <!--- Reject empty or malformed identity --->
    <cfif NOT len(username)>
      <cfset result.message = "Windows identity could not be parsed.">
      <cfreturn result>
    </cfif>

    <!--- Must exist in admin DB and be active --->
    <cfset accessUser = dao.getUserByCougarnet(username)>
    <cfif NOT structCount(accessUser) OR NOT val(accessUser.IS_ACTIVE)>
      <cfset result.message = "User not authorized - Not found in access list">
      <cfreturn result>
    </cfif>

    <!--- Load roles and permissions --->
    <cfset authorization = _loadAuthorizationContext(val(accessUser.USER_ID))>

    <cfif arrayLen(authorization.roles) EQ 0>
      <cfset result.message = "User not authorized - No access role assigned">
      <cfreturn result>
    </cfif>

    <!--- Build session user struct matching the LDAP path shape --->
    <cfset result.success = true>
    <cfset result.user = {
      adminUserID        = val(accessUser.USER_ID),
      username           = username,
      displayName        = (structKeyExists(accessUser, "DISPLAY_NAME") AND len(trim(accessUser.DISPLAY_NAME & "")) ? trim(accessUser.DISPLAY_NAME) : username),
      email              = (structKeyExists(accessUser, "EMAIL") ? trim(accessUser.EMAIL & "") : ""),
      department         = "",
      title              = "",
      phone              = "",
      authType           = "windows_integrated",
      loginAt            = now(),
      roles              = authorization.roles,
      roleIDs            = authorization.roleIDs,
      permissions        = authorization.permissions,
      actualRoles        = authorization.roles,
      actualRoleIDs      = authorization.roleIDs,
      actualPermissions  = authorization.permissions,
      actualIsSuperAdmin = authorization.isSuperAdmin,
      isSuperAdmin       = authorization.isSuperAdmin
    }>

    <cfset createSession(result.user)>

    <cfreturn result>
  </cffunction>

</cfcomponent>