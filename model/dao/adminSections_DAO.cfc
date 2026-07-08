component extends="dao.BaseDAO" output="false" {

    public any function init() {
        super.init();
        return this;
    }

    public boolean function hasSectionsTable() {
        var qry = executeQueryWithRetry(
            sql     = "SELECT CASE WHEN OBJECT_ID('dbo.AdminSectionPermissions','U') IS NOT NULL THEN 1 ELSE 0 END AS has_table",
            params  = {},
            options = { datasource = variables.dsn }
        );
        return val(qry.has_table) EQ 1;
    }

    public array function getAllSections() {
        if ( !hasSectionsTable() ) return [];

        var qry = executeQueryWithRetry(
            sql     = "
                SELECT
                    s.section_id,
                    s.section_key,
                    s.section_name,
                    s.section_path,
                    s.description,
                    s.sort_order,
                    s.is_system,
                    s.updated_at,
                    p.permission_id,
                    p.permission_key,
                    p.display_name   AS permission_display_name,
                    p.category       AS permission_category
                FROM dbo.AdminSectionPermissions s
                JOIN dbo.AdminPermissions p ON p.permission_id = s.permission_id
                ORDER BY s.sort_order, s.section_name
            ",
            params  = {},
            options = { datasource = variables.dsn }
        );
        return queryToArray(qry);
    }

    public struct function getSectionByKey(required string sectionKey) {
        if ( !hasSectionsTable() ) return {};

        var qry = executeQueryWithRetry(
            sql     = "
                SELECT
                    s.section_id,
                    s.section_key,
                    s.section_name,
                    s.section_path,
                    s.description,
                    s.sort_order,
                    s.is_system,
                    p.permission_id,
                    p.permission_key,
                    p.display_name AS permission_display_name
                FROM dbo.AdminSectionPermissions s
                JOIN dbo.AdminPermissions p ON p.permission_id = s.permission_id
                WHERE s.section_key = :sectionKey
            ",
            params  = { sectionKey = { value = arguments.sectionKey, cfsqltype = "cf_sql_varchar" } },
            options = { datasource = variables.dsn }
        );
        var arr = queryToArray(qry);
        return arrayLen(arr) ? arr[1] : {};
    }

    public void function updateSectionPermission(
        required numeric sectionId,
        required numeric permissionId
    ) {
        if ( !hasSectionsTable() ) return;

        executeQueryWithRetry(
            sql     = "
                UPDATE dbo.AdminSectionPermissions
                SET    permission_id = :permissionId,
                       updated_at    = GETDATE()
                WHERE  section_id    = :sectionId
            ",
            params  = {
                sectionId    = { value = arguments.sectionId,    cfsqltype = "cf_sql_integer" },
                permissionId = { value = arguments.permissionId, cfsqltype = "cf_sql_integer" }
            },
            options = { datasource = variables.dsn }
        );
    }

    /* Returns a flat array: each row has section data plus a roles array
       (all roles that have the section's required permission assigned).
       Used by the permission matrix view. */
    public array function getSectionsWithRoleMatrix() {
        if ( !hasSectionsTable() ) return [];

        var qry = executeQueryWithRetry(
            sql     = "
                SELECT
                    s.section_id,
                    s.section_key,
                    s.section_name,
                    s.sort_order,
                    p.permission_id,
                    p.permission_key,
                    p.display_name AS permission_display_name,
                    r.role_id,
                    r.role_name
                FROM dbo.AdminSectionPermissions s
                JOIN dbo.AdminPermissions p ON p.permission_id = s.permission_id
                LEFT JOIN dbo.AdminRolePermissions rp ON rp.permission_id = p.permission_id
                LEFT JOIN dbo.AdminRoles r ON r.role_id = rp.role_id
                ORDER BY s.sort_order, s.section_name, r.role_name
            ",
            params  = {},
            options = { datasource = variables.dsn }
        );
        return queryToArray(qry);
    }

}
