<!--- Intentionally barebones LDAP query shape to avoid fragility from optional cfldap args. --->
<cfldap
    action="QUERY"
    name="qResult"
    attributes="#ldapAttributes#"
    start="#searchStartDN#"
    scope="SUBTREE"
    server="#ldapServer#"
    filter="#ldapFilter#"
    username="#bindUsername#"
    password="#bindPassword#">
</cfldap>
