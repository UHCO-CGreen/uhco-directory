component output="false" {

    /**
     * adminAuth_service — Business logic for managing admin users and roles.
     * Wraps adminAuth_DAO with validation, LDAP lookup, and safety guards.
     */

    public any function init() {
        variables.dao = createObject("component", "dao.adminAuth_DAO").init();
        return this;
    }

    /* ─────────────────── Roles ─────────────────── */

    public array function getAllRoles() {
        return variables.dao.getAllRoles();
    }

    public struct function getRoleByID(required numeric roleID) {
        return variables.dao.getRoleByID(arguments.roleID);
    }

    public struct function createRole(required string roleName) {
        var result = { success = false, message = "", roleID = 0 };
        var name = uCase(trim(arguments.roleName));

        if (len(name) == 0) {
            result.message = "Role name is required.";
            return result;
        }

        // Check for duplicate
        var existing = variables.dao.getRoleByName(name);
        if (structCount(existing)) {
            result.message = "A role named '#name#' already exists.";
            return result;
        }

        result.roleID  = variables.dao.createRole(name);
        result.success  = true;
        result.message  = "Role '#name#' created.";
        return result;
    }

    public struct function updateRole(required numeric roleID, required string roleName) {
        var result = { success = false, message = "" };
        var name = uCase(trim(arguments.roleName));

        if (len(name) == 0) {
            result.message = "Role name is required.";
            return result;
        }

        var existing = variables.dao.getRoleByName(name);
        if (structCount(existing) AND existing.ROLE_ID != arguments.roleID) {
            result.message = "A role named '#name#' already exists.";
            return result;
        }

        variables.dao.updateRole(arguments.roleID, name);
        result.success = true;
        result.message = "Role updated.";
        return result;
    }

    public struct function deleteRole(required numeric roleID) {
        var result = { success = false, message = "" };

        var role = variables.dao.getRoleByID(arguments.roleID);
        if (!structCount(role)) {
            result.message = "Role not found.";
            return result;
        }

        // Prevent deleting SUPER_ADMIN
        if (role.ROLE_NAME == "SUPER_ADMIN") {
            result.message = "The SUPER_ADMIN role cannot be deleted.";
            return result;
        }

        variables.dao.deleteRole(arguments.roleID);
        result.success = true;
        result.message = "Role '#role.ROLE_NAME#' deleted.";
        return result;
    }

    /* ─────────────────── Permissions ─────────────────── */

    public array function getAllPermissions() {
        return variables.dao.getAllPermissions();
    }

    public struct function getPermissionByKey(required string permissionKey) {
        return variables.dao.getPermissionByKey(arguments.permissionKey);
    }

    public struct function getPermissionByID(required numeric permissionID) {
        return variables.dao.getPermissionByID(arguments.permissionID);
    }

    public struct function createPermission(
        required string permissionKey,
        required string displayName,
        required string category,
        string description = "",
        numeric sortOrder = 0,
        boolean isActive = true
    ) {
        var result = { success = false, message = "", permissionID = 0 };
        var keyName = lCase(trim(arguments.permissionKey));
        var displayLabel = trim(arguments.displayName);
        var categoryName = lCase(trim(arguments.category));
        var existing = {};

        if (!len(keyName)) {
            result.message = "Permission key is required.";
            return result;
        }

        if (!reFind("^[a-z0-9_.]+$", keyName)) {
            result.message = "Permission key may only contain lowercase letters, numbers, underscores, and periods.";
            return result;
        }

        if (!len(displayLabel)) {
            result.message = "Display name is required.";
            return result;
        }

        if (!len(categoryName)) {
            result.message = "Category is required.";
            return result;
        }

        existing = variables.dao.getPermissionByKey(keyName);
        if (structCount(existing)) {
            result.message = "A permission with key '#keyName#' already exists.";
            return result;
        }

        result.permissionID = variables.dao.createPermission(
            permissionKey = keyName,
            displayName = displayLabel,
            category = categoryName,
            description = trim(arguments.description),
            sortOrder = val(arguments.sortOrder),
            isActive = arguments.isActive,
            isSystem = false
        );
        result.success = true;
        result.message = "Permission '#keyName#' created.";
        return result;
    }

    public struct function updatePermission(
        required numeric permissionID,
        required string permissionKey,
        required string displayName,
        required string category,
        string description = "",
        numeric sortOrder = 0,
        boolean isActive = true
    ) {
        var result = { success = false, message = "" };
        var keyName = lCase(trim(arguments.permissionKey));
        var displayLabel = trim(arguments.displayName);
        var categoryName = lCase(trim(arguments.category));
        var permissionRecord = variables.dao.getPermissionByID(arguments.permissionID);
        var existing = {};

        if (!structCount(permissionRecord)) {
            result.message = "Permission not found.";
            return result;
        }

        if (!len(displayLabel)) {
            result.message = "Display name is required.";
            return result;
        }

        if (!len(categoryName)) {
            result.message = "Category is required.";
            return result;
        }

        if (!len(keyName)) {
            result.message = "Permission key is required.";
            return result;
        }

        if (!reFind("^[a-z0-9_.]+$", keyName)) {
            result.message = "Permission key may only contain lowercase letters, numbers, underscores, and periods.";
            return result;
        }

        if (val(permissionRecord.IS_SYSTEM) EQ 1 AND keyName != lCase(trim(permissionRecord.PERMISSION_KEY))) {
            result.message = "System permission keys cannot be renamed.";
            return result;
        }

        existing = variables.dao.getPermissionByKey(keyName);
        if (structCount(existing) AND existing.PERMISSION_ID != arguments.permissionID) {
            result.message = "A permission with key '#keyName#' already exists.";
            return result;
        }

        variables.dao.updatePermission(
            permissionID = arguments.permissionID,
            permissionKey = keyName,
            displayName = displayLabel,
            category = categoryName,
            description = trim(arguments.description),
            sortOrder = val(arguments.sortOrder),
            isActive = arguments.isActive
        );
        result.success = true;
        result.message = "Permission updated.";
        return result;
    }

    public struct function deletePermission(required numeric permissionID) {
        var result = { success = false, message = "" };
        var permissionRecord = variables.dao.getPermissionByID(arguments.permissionID);

        if (!structCount(permissionRecord)) {
            result.message = "Permission not found.";
            return result;
        }

        if (val(permissionRecord.IS_SYSTEM) EQ 1) {
            result.message = "System permissions cannot be deleted.";
            return result;
        }

        variables.dao.deletePermission(arguments.permissionID);
        result.success = true;
        result.message = "Permission '#permissionRecord.PERMISSION_KEY#' deleted.";
        return result;
    }

    public array function getPermissionsForRole(required numeric roleID) {
        return variables.dao.getPermissionsForRole(arguments.roleID);
    }

    public struct function saveRolePermissions(required numeric roleID, required array permissionIDArray) {
        var result = { success = false, message = "" };
        var role = variables.dao.getRoleByID(arguments.roleID);
        var existingPermissions = [];
        var existingPermissionIDs = {};
        var requestedPermissionIDs = {};
        var permissionRow = {};
        var requestedPermissionID = 0;

        if (!structCount(role)) {
            result.message = "Role not found.";
            return result;
        }

        existingPermissions = variables.dao.getPermissionsForRole(arguments.roleID);
        for (permissionRow in existingPermissions) {
            existingPermissionIDs[toString(permissionRow.PERMISSION_ID)] = true;
        }

        for (requestedPermissionID in arguments.permissionIDArray) {
            if (isNumeric(requestedPermissionID) AND val(requestedPermissionID) GT 0) {
                requestedPermissionIDs[toString(val(requestedPermissionID))] = true;
            }
        }

        for (permissionRow in existingPermissions) {
            if (!structKeyExists(requestedPermissionIDs, toString(permissionRow.PERMISSION_ID))) {
                variables.dao.revokePermissionFromRole(arguments.roleID, permissionRow.PERMISSION_ID);
            }
        }

        for (requestedPermissionID in arguments.permissionIDArray) {
            if (isNumeric(requestedPermissionID) AND val(requestedPermissionID) GT 0 AND !structKeyExists(existingPermissionIDs, toString(val(requestedPermissionID)))) {
                variables.dao.assignPermissionToRole(arguments.roleID, val(requestedPermissionID));
            }
        }

        result.success = true;
        result.message = "Role permissions updated.";
        return result;
    }

    /* ─────────────────── Users ─────────────────── */

    public array function getAllUsers() {
        return variables.dao.getAllUsers();
    }

    public struct function getUserByID(required numeric userID) {
        return variables.dao.getUserByID(arguments.userID);
    }

    public struct function addUser(required string cougarnet) {
        var result = { success = false, message = "", userID = 0 };
        var cn = lCase(trim(arguments.cougarnet));

        if (len(cn) == 0) {
            result.message = "CougarNet username is required.";
            return result;
        }

        // Check for existing (including inactive)
        var existing = variables.dao.getUserByCougarnet(cn);
        if (structCount(existing)) {
            if (existing.IS_ACTIVE) {
                result.message = "User '#cn#' already exists and is active.";
            } else {
                // Reactivate
                variables.dao.setUserActive(existing.USER_ID, true);
                result.userID  = existing.USER_ID;
                result.success = true;
                result.message = "User '#cn#' reactivated.";
            }
            return result;
        }

        // Validate via LDAP that user exists in CougarNet
        var ldapValid = validateCougarnet(cn);
        if (!ldapValid.found) {
            result.message = "CougarNet user '#cn#' not found in directory. #ldapValid.detail#";
            return result;
        }

        result.userID  = variables.dao.createUser(cn);
        result.success = true;
        result.message = "User '#cn#' (#ldapValid.displayName#) added.";
        return result;
    }

    public struct function toggleUserActive(required numeric userID) {
        var result = { success = false, message = "" };
        var user = variables.dao.getUserByID(arguments.userID);

        if (!structCount(user)) {
            result.message = "User not found.";
            return result;
        }

        var newActive = !user.IS_ACTIVE;

        // Prevent deactivating the last active SUPER_ADMIN
        if (!newActive) {
            var roles = variables.dao.getRolesForUser(arguments.userID);
            var isSA = false;
            for (var r in roles) {
                if (r.ROLE_NAME == "SUPER_ADMIN") { isSA = true; break; }
            }
            if (isSA) {
                var saCount = variables.dao.countUsersWithRole("SUPER_ADMIN");
                if (saCount <= 1) {
                    result.message = "Cannot deactivate the last active SUPER_ADMIN.";
                    return result;
                }
            }
        }

        variables.dao.setUserActive(arguments.userID, newActive);
        result.success = true;
        result.message = "User '#user.COUGARNET#' " & (newActive ? "activated" : "deactivated") & ".";
        return result;
    }

    /* ─────────────────── Role Assignments ─────────────────── */

    public array function getRolesForUser(required numeric userID) {
        return variables.dao.getRolesForUser(arguments.userID);
    }

    public struct function assignRole(required numeric userID, required numeric roleID) {
        var result = { success = false, message = "" };
        variables.dao.assignRole(arguments.userID, arguments.roleID);
        result.success = true;
        result.message = "Role assigned.";
        return result;
    }

    public struct function revokeRole(required numeric userID, required numeric roleID) {
        var result = { success = false, message = "" };

        // Prevent revoking SUPER_ADMIN if it leaves zero active super admins
        var role = variables.dao.getRoleByID(arguments.roleID);
        if (structCount(role) AND role.ROLE_NAME == "SUPER_ADMIN") {
            var saCount = variables.dao.countUsersWithRole("SUPER_ADMIN");
            if (saCount <= 1) {
                result.message = "Cannot revoke the last SUPER_ADMIN role assignment.";
                return result;
            }
        }

        variables.dao.revokeRole(arguments.userID, arguments.roleID);
        result.success = true;
        result.message = "Role revoked.";
        return result;
    }

    public array function getDirectPermissionsForUser(required numeric userID) {
        return variables.dao.getDirectPermissionsForUser(arguments.userID);
    }

    public array function getEffectivePermissionsForUser(required numeric userID) {
        return variables.dao.getEffectivePermissionsForUser(arguments.userID);
    }

    public struct function saveUserDirectPermissions(required numeric userID, required array permissionIDArray, numeric grantedByUserID = 0) {
        var result = { success = false, message = "" };
        var user = variables.dao.getUserByID(arguments.userID);
        var existingPermissions = [];
        var existingPermissionIDs = {};
        var requestedPermissionIDs = {};
        var permissionRow = {};
        var requestedPermissionID = 0;

        if (!structCount(user)) {
            result.message = "User not found.";
            return result;
        }

        existingPermissions = variables.dao.getDirectPermissionsForUser(arguments.userID);
        for (permissionRow in existingPermissions) {
            existingPermissionIDs[toString(permissionRow.PERMISSION_ID)] = true;
        }

        for (requestedPermissionID in arguments.permissionIDArray) {
            if (isNumeric(requestedPermissionID) AND val(requestedPermissionID) GT 0) {
                requestedPermissionIDs[toString(val(requestedPermissionID))] = true;
            }
        }

        for (permissionRow in existingPermissions) {
            if (!structKeyExists(requestedPermissionIDs, toString(permissionRow.PERMISSION_ID))) {
                variables.dao.revokePermissionFromUser(arguments.userID, permissionRow.PERMISSION_ID);
            }
        }

        for (requestedPermissionID in arguments.permissionIDArray) {
            if (isNumeric(requestedPermissionID) AND val(requestedPermissionID) GT 0 AND !structKeyExists(existingPermissionIDs, toString(val(requestedPermissionID)))) {
                variables.dao.grantPermissionToUser(arguments.userID, val(requestedPermissionID), arguments.grantedByUserID);
            }
        }

        result.success = true;
        result.message = "Direct user permissions updated.";
        return result;
    }

    /* ─────────────────── Private ─────────────────── */

    private struct function validateCougarnet(required string username) {
        var result = { found = false, displayName = "", detail = "" };
        try {
            var qUser = "";
            cfldap(
                action      = "QUERY",
                name        = "qUser",
                attributes  = "displayName,sAMAccountName",
                start       = "DC=cougarnet,DC=uh,DC=edu",
                scope       = "SUBTREE",
                maxrows     = "1",
                server      = "cougarnet.uh.edu",
                filter      = "(&(objectClass=user)(sAMAccountName=#arguments.username#))",
                username    = "COUGARNET\uhcoweb",
                password    = "5E9##WN!ag"
            );
            if (qUser.recordCount GT 0) {
                result.found       = true;
                result.displayName = qUser.displayName;
            }
        } catch (any e) {
            result.detail = e.message;
        }
        return result;
    }

}
