<cfquery datasource="UHCO_Directory">
    INSERT INTO ExternalSystems (SystemName)
    VALUES (<cfqueryparam cfsqltype="cf_sql_varchar" value="#form.SystemName#">)
</cfquery>

<cflocation url="/dir/admin/external/index.cfm" addtoken="false">