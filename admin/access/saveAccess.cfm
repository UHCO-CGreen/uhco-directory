<cfquery datasource="UHCO_Directory">
    INSERT INTO AccessAreas (AccessName)
    VALUES (<cfqueryparam value="#form.AccessName#" cfsqltype="cf_sql_varchar">)
</cfquery>

<cflocation url="/admin/access/index.cfm" addtoken="false">