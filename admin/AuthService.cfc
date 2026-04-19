<cfcomponent displayname="AuthService" output="false">

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

    <cftry>
      <cfldap
        action="QUERY"
        name="GetUserInfo"
        attributes="displayName,memberOf,sAMAccountName,mail,telephoneNumber,accountExpires,userAccountControl,department,title,initials"
        start="DC=cougarnet,DC=uh,DC=edu"
        scope="SUBTREE"
        filter="(&(objectClass=User)(objectCategory=Person)(sAMAccountName=#arguments.username#)(|(memberOf=CN=OPT-ASC,OU=ASC USERS,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-STAFF,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-OPTOMETRY,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-FACULTY-1,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-CLASS2022,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-CLASS2023,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-CLASS2024,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-CLASS2025,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)(memberOf=CN=OPT-CLASS2026,OU=Distribution Groups,OU=OPTOMETRY,DC=cougarnet,DC=uh,DC=edu)))"
        maxrows="1"
        server="cougarnet.uh.edu"
        username="COUGARNET\#arguments.username#"
        password="#arguments.password#">
  
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
      <cfset var accessUser = adminAuthDAO.getUserByCougarnet(lCase(trim(GetUserInfo.sAMAccountName & "")))>
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
          file="ldap-debug"
          type="error"
          text="LDAP ERROR: #cfcatch.message# | #cfcatch.detail#"
        >
        <cfif cfcatch.message CONTAINS "error code 49">
          <cfif cfcatch.message CONTAINS "52e">
            <cfset result.message = "Invalid credentials. Please check your username or password and try again.">
          <cfelseif cfcatch.message CONTAINS "525">
            <cfset result.message = "User not found. Please check your username and try again.">
          <cfelseif cfcatch.message CONTAINS "530">
            <cfset result.message = "Not permitted to log on at this time. Please contact your IT admin.">
          <cfelseif cfcatch.message CONTAINS "532">
            <cfset result.message = "Password expired. Please change your password before attempting to log in again.">
          <cfelseif cfcatch.message CONTAINS "533">
            <cfset result.message = "Account disabled. Please contact your IT admin.">
          <cfelseif cfcatch.message CONTAINS "701">
            <cfset result.message = "Account expired. Please contact your IT admin.">
          <cfelseif cfcatch.message CONTAINS "773">
            <cfset result.message = "You must reset your password before logging in.">
          <cfelse>
            <cfset result.message = "Login failed (code 49). Please try again.">
          </cfif>
        <cfelse>
          <cfset result.message = "Authentication error. Please try again. #cfcatch.message# | #cfcatch.detail#">
        </cfif>
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

        <cfset session.user = _normalizeSessionUser(arguments.user)>
    </cffunction>

    <cffunction
        name="logout"
        access="public"
        returntype="void"
        output="false"
        >
        <!--- Clear user session data --->
        <cfif structKeyExists(session, "user")>
            <cfset structDelete(session, "user")>
        </cfif>

        <!--- Optional but recommended: rotate session ID --->
        <cfset sessionInvalidate()>
        </cffunction>

</cfcomponent>