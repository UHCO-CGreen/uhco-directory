component extends="dao.BaseDAO" output="false" {

    /**
     * adminAuth_DAO — CRUD for AdminUsers, AdminRoles, AdminUserRoles
     */

    public any function init() {
        super.init();        return this;
    }

    public boolean function hasPermissionTables() {
        var qry = executeQueryWithRetry(
            sql     = "
                SELECT CASE
                    WHEN OBJECT_ID('dbo.AdminPermissions', 'U') IS NOT NULL
                     AND OBJECT_ID('dbo.AdminRolePermissions', 'U') IS NOT NULL
                     AND OBJECT_ID('dbo.AdminUserPermissions', 'U') IS NOT NULL
                    THEN 1 ELSE 0 END AS has_tables
            ",
            params  = {},
            options = { datasource = variables.dsn }
        );
        return val(qry.has_tables) EQ 1;
    }

    /* ─────────────────── AdminRoles ─────────────────── */

    public array function getAllRoles() {
        var qry = executeQueryWithRetry(
            sql     = "SELECT role_id, role_name FROM AdminRoles ORDER BY role_name",
            params  = {},
            options = { datasource = variables.dsn }
        );
        return queryToArray(qry);
    }

    public struct function getRoleByID(required numeric roleID) {
        var qry = executeQueryWithRetry(
            sql     = "SELECT role_id, role_name FROM AdminRoles WHERE role_id = :roleID",
            params  = { roleID = { value = arguments.roleID, cfsqltype = "cf_sql_integer" } },
            options = { datasource = variables.dsn }
        );
        var arr = queryToArray(qry);
        return arrayLen(arr) ? arr[1] : {};
    }

    public struct function getRoleByName(required string roleName) {
        var qry = executeQueryWithRetry(
            sql     = "SELECT role_id, role_name FROM AdminRoles WHERE role_name = :roleName",
            params  = { roleName = { value = arguments.roleName, cfsqltype = "cf_sql_varchar" } },
            options = { datasource = variables.dsn }
        );
        var arr = queryToArray(qry);
        return arrayLen(arr) ? arr[1] : {};
    }

    public numeric function createRole(required string roleName) {
        var qry = executeQueryWithRetry(
            sql     = "INSERT INTO AdminRoles (role_name) OUTPUT INSERTED.role_id VALUES (:roleName)",
            params  = { roleName = { value = arguments.roleName, cfsqltype = "cf_sql_varchar" } },
            options = { datasource = variables.dsn }
        );
        return qry.role_id;
    }

    public void function updateRole(required numeric roleID, required string roleName) {
        executeQueryWithRetry(
            sql     = "UPDATE AdminRoles SET role_name = :roleName WHERE role_id = :roleID",
            params  = {
                roleID   = { value = arguments.roleID,   cfsqltype = "cf_sql_integer" },
                roleName = { value = arguments.roleName, cfsqltype = "cf_sql_varchar" }
            },
            options = { datasource = variables.dsn }
        );
    }

    public void function deleteRole(required numeric roleID) {
        executeQueryWithRetry(
            sql     = "DELETE FROM AdminUserRoles WHERE role_id = :roleID",
            params  = { roleID = { value = arguments.roleID, cfsqltype = "cf_sql_integer" } },
            options = { datasource = variables.dsn }
        );
        executeQueryWithRetry(
            sql     = "DELETE FROM AdminRoles WHERE role_id = :roleID",
            params  = { roleID = { value = arguments.roleID, cfsqltype = "cf_sql_integer" } },
            options = { datasource = variables.dsn }
        );
    }

    public array function getAllPermissions() {
        if ( !hasPermissionTables() ) {
            return [];
        }

        var qry = executeQueryWithRetry(
            sql     = "
                SELECT permission_id, permission_key, display_name, category, description, is_system, is_active, sort_order
                FROM AdminPermissions
                ORDER BY category, sort_order, permission_key
            ",
            params  = {},
            options = { datasource = variables.dsn }
        );
        return queryToArray(qry);
    }

    public struct function getPermissionByKey(required string permissionKey) {
        if ( !hasPermissionTables() ) {
            return {};
        }

        var qry = executeQueryWithRetry(
            sql     = "
                SELECT permission_id, permission_key, display_name, category, description, is_system, is_active, sort_order
                FROM AdminPermissions
                WHERE permission_key = :permissionKey
            ",
            params  = { permissionKey = { value = arguments.permissionKey, cfsqltype = "cf_sql_varchar" } },
            options = { datasource = variables.dsn }
        );
        var arr = queryToArray(qry);
        return arrayLen(arr) ? arr[1] : {};
    }

    public struct function getPermissionByID(required numeric permissionID) {
        if ( !hasPermissionTables() ) {
            return {};
        }

        var qry = executeQueryWithRetry(
            sql     = "
                SELECT permission_id, permission_key, display_name, category, description, is_system, is_active, sort_order
                FROM AdminPermissions
                WHERE permission_id = :permissionID
            ",
            params  = { permissionID = { value = arguments.permissionID, cfsqltype = "cf_sql_integer" } },
            options = { datasource = variables.dsn }
        );
        var arr = queryToArray(qry);
        return arrayLen(arr) ? arr[1] : {};
    }

    public numeric function createPermission(
        required string permissionKey,
        required string displayName,
        required string category,
        string description = "",
        numeric sortOrder = 0,
        boolean isActive = true,
        boolean isSystem = false
    ) {
        if ( !hasPermissionTables() ) {
            return 0;
        }

        var qry = executeQueryWithRetry(
            sql     = "
                INSERT INTO AdminPermissions (
                    permission_key,
                    display_name,
                    category,
                    description,
                    is_system,
                    is_active,
                    sort_order,
                    updated_at
                )
                OUTPUT INSERTED.permission_id
                VALUES (
                    :permissionKey,
                    :displayName,
                    :category,
                    :description,
                    :isSystem,
                    :isActive,
                    :sortOrder,
                    GETDATE()
                )
            ",
            params  = {
                permissionKey = { value = arguments.permissionKey, cfsqltype = "cf_sql_varchar" },
                displayName = { value = arguments.displayName, cfsqltype = "cf_sql_varchar" },
                category = { value = arguments.category, cfsqltype = "cf_sql_varchar" },
                description = { value = arguments.description, null = !len(trim(arguments.description)), cfsqltype = "cf_sql_varchar" },
                isSystem = { value = arguments.isSystem ? 1 : 0, cfsqltype = "cf_sql_integer" },
                isActive = { value = arguments.isActive ? 1 : 0, cfsqltype = "cf_sql_integer" },
                sortOrder = { value = arguments.sortOrder, cfsqltype = "cf_sql_integer" }
            },
            options = { datasource = variables.dsn }
        );
        return val(qry.permission_id);
    }

    public void function updatePermission(
        required numeric permissionID,
        required string permissionKey,
        required string displayName,
        required string category,
        string description = "",
        numeric sortOrder = 0,
        boolean isActive = true
    ) {
        if ( !hasPermissionTables() ) {
            return;
        }

        executeQueryWithRetry(
            sql     = "
                UPDATE AdminPermissions
                SET permission_key = :permissionKey,
                    display_name = :displayName,
                    category = :category,
                    description = :description,
                    is_active = :isActive,
                    sort_order = :sortOrder,
                    updated_at = GETDATE()
                WHERE permission_id = :permissionID
            ",
            params  = {
                permissionID = { value = arguments.permissionID, cfsqltype = "cf_sql_integer" },
                permissionKey = { value = arguments.permissionKey, cfsqltype = "cf_sql_varchar" },
                displayName = { value = arguments.displayName, cfsqltype = "cf_sql_varchar" },
                category = { value = arguments.category, cfsqltype = "cf_sql_varchar" },
                description = { value = arguments.description, null = !len(trim(arguments.description)), cfsqltype = "cf_sql_varchar" },
                isActive = { value = arguments.isActive ? 1 : 0, cfsqltype = "cf_sql_integer" },
                sortOrder = { value = arguments.sortOrder, cfsqltype = "cf_sql_integer" }
            },
            options = { datasource = variables.dsn }
        );
    }

    public void function deletePermission(required numeric permissionID) {
        if ( !hasPermissionTables() ) {
            return;
        }

        executeQueryWithRetry(
            sql     = "DELETE FROM AdminPermissions WHERE permission_id = :permissionID",
            params  = { permissionID = { value = arguments.permissionID, cfsqltype = "cf_sql_integer" } },
            options = { datasource = variables.dsn }
        );
    }

    public array function getPermissionsForRole(required numeric roleID) {
        if ( !hasPermissionTables() ) {
            return [];
        }

        var qry = executeQueryWithRetry(
            sql     = "
                SELECT p.permission_id, p.permission_key, p.display_name, p.category, p.description, p.sort_order
                FROM AdminRolePermissions arp
                INNER JOIN AdminPermissions p ON p.permission_id = arp.permission_id
                WHERE arp.role_id = :roleID
                  AND p.is_active = 1
                ORDER BY p.category, p.sort_order, p.permission_key
            ",
            params  = { roleID = { value = arguments.roleID, cfsqltype = "cf_sql_integer" } },
            options = { datasource = variables.dsn }
        );
        return queryToArray(qry);
    }

    public void function assignPermissionToRole(required numeric roleID, required numeric permissionID) {
        if ( !hasPermissionTables() ) {
            return;
        }

        executeQueryWithRetry(
            sql     = "
                IF NOT EXISTS (
                    SELECT 1
                    FROM AdminRolePermissions
                    WHERE role_id = :roleID AND permission_id = :permissionID
                )
                INSERT INTO AdminRolePermissions (role_id, permission_id)
                VALUES (:roleID, :permissionID)
            ",
            params  = {
                roleID = { value = arguments.roleID, cfsqltype = "cf_sql_integer" },
                permissionID = { value = arguments.permissionID, cfsqltype = "cf_sql_integer" }
            },
            options = { datasource = variables.dsn }
        );
    }

    public void function revokePermissionFromRole(required numeric roleID, required numeric permissionID) {
        if ( !hasPermissionTables() ) {
            return;
        }

        executeQueryWithRetry(
            sql     = "DELETE FROM AdminRolePermissions WHERE role_id = :roleID AND permission_id = :permissionID",
            params  = {
                roleID = { value = arguments.roleID, cfsqltype = "cf_sql_integer" },
                permissionID = { value = arguments.permissionID, cfsqltype = "cf_sql_integer" }
            },
            options = { datasource = variables.dsn }
        );
    }

    /* ─────────────────── AdminUsers ─────────────────── */

    public array function getAllUsers() {
        var qry = executeQueryWithRetry(
            sql     = "
                SELECT  u.user_id, u.cougarnet, u.is_active,
                        STUFF((
                            SELECT ', ' + r.role_name
                            FROM AdminUserRoles ur
                            JOIN AdminRoles r ON r.role_id = ur.role_id
                            WHERE ur.user_id = u.user_id
                            FOR XML PATH(''), TYPE
                        ).value('.','nvarchar(max)'), 1, 2, '') AS role_names,
                        STUFF((
                            SELECT ',' + CAST(r.role_id AS VARCHAR)
                            FROM AdminUserRoles ur
                            JOIN AdminRoles r ON r.role_id = ur.role_id
                            WHERE ur.user_id = u.user_id
                            FOR XML PATH(''), TYPE
                        ).value('.','nvarchar(max)'), 1, 1, '') AS role_ids
                FROM AdminUsers u
                ORDER BY u.cougarnet
            ",
            params  = {},
            options = { datasource = variables.dsn }
        );
        return queryToArray(qry);
    }

    public struct function getUserByID(required numeric userID) {
        var qry = executeQueryWithRetry(
            sql     = "SELECT user_id, cougarnet, is_active FROM AdminUsers WHERE user_id = :userID",
            params  = { userID = { value = arguments.userID, cfsqltype = "cf_sql_integer" } },
            options = { datasource = variables.dsn }
        );
        var arr = queryToArray(qry);
        return arrayLen(arr) ? arr[1] : {};
    }

    public struct function getUserByCougarnet(required string cougarnet) {
        var qry = executeQueryWithRetry(
            sql     = "SELECT user_id, cougarnet, is_active FROM AdminUsers WHERE cougarnet = :cn",
            params  = { cn = { value = arguments.cougarnet, cfsqltype = "cf_sql_varchar" } },
            options = { datasource = variables.dsn }
        );
        var arr = queryToArray(qry);
        return arrayLen(arr) ? arr[1] : {};
    }

    public numeric function createUser(required string cougarnet) {
        var qry = executeQueryWithRetry(
            sql     = "INSERT INTO AdminUsers (cougarnet, is_active) OUTPUT INSERTED.user_id VALUES (:cn, 1)",
            params  = { cn = { value = arguments.cougarnet, cfsqltype = "cf_sql_varchar" } },
            options = { datasource = variables.dsn }
        );
        return qry.user_id;
    }

    public void function setUserActive(required numeric userID, required boolean isActive) {
        executeQueryWithRetry(
            sql     = "UPDATE AdminUsers SET is_active = :active WHERE user_id = :userID",
            params  = {
                userID = { value = arguments.userID,                        cfsqltype = "cf_sql_integer" },
                active = { value = arguments.isActive ? 1 : 0,             cfsqltype = "cf_sql_integer" }
            },
            options = { datasource = variables.dsn }
        );
    }

    public void function deleteUser(required numeric userID) {
        executeQueryWithRetry(
            sql     = "DELETE FROM AdminUserRoles WHERE user_id = :userID",
            params  = { userID = { value = arguments.userID, cfsqltype = "cf_sql_integer" } },
            options = { datasource = variables.dsn }
        );
        executeQueryWithRetry(
            sql     = "DELETE FROM AdminUsers WHERE user_id = :userID",
            params  = { userID = { value = arguments.userID, cfsqltype = "cf_sql_integer" } },
            options = { datasource = variables.dsn }
        );
    }

    /* ─────────────────── AdminUserRoles ─────────────────── */

    public array function getRolesForUser(required numeric userID) {
        var qry = executeQueryWithRetry(
            sql     = "
                SELECT r.role_id, r.role_name
                FROM AdminUserRoles ur
                JOIN AdminRoles r ON r.role_id = ur.role_id
                WHERE ur.user_id = :userID
                ORDER BY r.role_name
            ",
            params  = { userID = { value = arguments.userID, cfsqltype = "cf_sql_integer" } },
            options = { datasource = variables.dsn }
        );
        return queryToArray(qry);
    }

    public void function assignRole(required numeric userID, required numeric roleID) {
        executeQueryWithRetry(
            sql     = "
                IF NOT EXISTS (
                    SELECT 1 FROM AdminUserRoles
                    WHERE user_id = :userID AND role_id = :roleID
                )
                INSERT INTO AdminUserRoles (user_id, role_id) VALUES (:userID, :roleID)
            ",
            params  = {
                userID = { value = arguments.userID, cfsqltype = "cf_sql_integer" },
                roleID = { value = arguments.roleID, cfsqltype = "cf_sql_integer" }
            },
            options = { datasource = variables.dsn }
        );
    }

    public void function revokeRole(required numeric userID, required numeric roleID) {
        executeQueryWithRetry(
            sql     = "DELETE FROM AdminUserRoles WHERE user_id = :userID AND role_id = :roleID",
            params  = {
                userID = { value = arguments.userID, cfsqltype = "cf_sql_integer" },
                roleID = { value = arguments.roleID, cfsqltype = "cf_sql_integer" }
            },
            options = { datasource = variables.dsn }
        );
    }

    public array function getDirectPermissionsForUser(required numeric userID) {
        if ( !hasPermissionTables() ) {
            return [];
        }

        var qry = executeQueryWithRetry(
            sql     = "
                SELECT p.permission_id, p.permission_key, p.display_name, p.category, p.description, p.sort_order
                FROM AdminUserPermissions aup
                INNER JOIN AdminPermissions p ON p.permission_id = aup.permission_id
                WHERE aup.user_id = :userID
                  AND p.is_active = 1
                ORDER BY p.category, p.sort_order, p.permission_key
            ",
            params  = { userID = { value = arguments.userID, cfsqltype = "cf_sql_integer" } },
            options = { datasource = variables.dsn }
        );
        return queryToArray(qry);
    }

    public void function grantPermissionToUser(required numeric userID, required numeric permissionID, numeric grantedByUserID = 0, string notes = "") {
        if ( !hasPermissionTables() ) {
            return;
        }

        executeQueryWithRetry(
            sql     = "
                IF NOT EXISTS (
                    SELECT 1
                    FROM AdminUserPermissions
                    WHERE user_id = :userID AND permission_id = :permissionID
                )
                INSERT INTO AdminUserPermissions (user_id, permission_id, granted_by_user_id, notes)
                VALUES (:userID, :permissionID, :grantedByUserID, :notes)
            ",
            params  = {
                userID = { value = arguments.userID, cfsqltype = "cf_sql_integer" },
                permissionID = { value = arguments.permissionID, cfsqltype = "cf_sql_integer" },
                grantedByUserID = { value = arguments.grantedByUserID, null = (arguments.grantedByUserID LTE 0), cfsqltype = "cf_sql_integer" },
                notes = { value = arguments.notes, null = !len(trim(arguments.notes)), cfsqltype = "cf_sql_varchar" }
            },
            options = { datasource = variables.dsn }
        );
    }

    public void function revokePermissionFromUser(required numeric userID, required numeric permissionID) {
        if ( !hasPermissionTables() ) {
            return;
        }

        executeQueryWithRetry(
            sql     = "DELETE FROM AdminUserPermissions WHERE user_id = :userID AND permission_id = :permissionID",
            params  = {
                userID = { value = arguments.userID, cfsqltype = "cf_sql_integer" },
                permissionID = { value = arguments.permissionID, cfsqltype = "cf_sql_integer" }
            },
            options = { datasource = variables.dsn }
        );
    }

    public array function getEffectivePermissionsForUser(required numeric userID) {
        if ( !hasPermissionTables() ) {
            return [];
        }

        var qry = executeQueryWithRetry(
            sql     = "
                SELECT DISTINCT permission_key, category, sort_order
                FROM (
                    SELECT p.permission_key, p.category, p.sort_order
                    FROM AdminUserRoles aur
                    INNER JOIN AdminRolePermissions arp ON arp.role_id = aur.role_id
                    INNER JOIN AdminPermissions p ON p.permission_id = arp.permission_id
                    WHERE aur.user_id = :userID
                      AND p.is_active = 1

                    UNION

                    SELECT p.permission_key, p.category, p.sort_order
                    FROM AdminUserPermissions aup
                    INNER JOIN AdminPermissions p ON p.permission_id = aup.permission_id
                    WHERE aup.user_id = :userID
                      AND p.is_active = 1
                ) permissions
                ORDER BY category, sort_order, permission_key
            ",
            params  = { userID = { value = arguments.userID, cfsqltype = "cf_sql_integer" } },
            options = { datasource = variables.dsn }
        );
        return queryToArray(qry);
    }

    public numeric function countUsersWithRole(required string roleName) {
        var qry = executeQueryWithRetry(
            sql     = "
                SELECT COUNT(*) AS cnt
                FROM AdminUserRoles ur
                JOIN AdminRoles r ON r.role_id = ur.role_id
                JOIN AdminUsers u ON u.user_id = ur.user_id
                WHERE r.role_name = :roleName AND u.is_active = 1
            ",
            params  = { roleName = { value = arguments.roleName, cfsqltype = "cf_sql_varchar" } },
            options = { datasource = variables.dsn }
        );
        return qry.cnt;
    }

}
