<cfoutput>
<cftry>
    <cfset dao = createObject("component", "dir.dao.users_DAO").init()>
    <cfset users = dao.getAllUsers()>
    
    <h2>Diagnostic Output</h2>
    <p>Number of users returned: #arrayLen(users)#</p>
    
    <cfif arrayLen(users) gt 0>
        <h3>First User Structure:</h3>
        <cfdump var="#users[1]#" />
        
        <h3>First User Keys:</h3>
        <ul>
            <cfloop list="#structKeyList(users[1])#" item="key">
                <li>#key# = #users[1][key]#</li>
            </cfloop>
        </ul>
    </cfif>
    
    <cfcatch>
        <p>Error: #cfcatch.message#</p>
        <cfdump var="#cfcatch#" />
    </cfcatch>
</cftry>
</cfoutput>