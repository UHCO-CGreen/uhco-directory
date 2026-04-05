<cfsilent>
    <!--- Clear all cached components --->
    <cfset StructClear(application) />
</cfsilent>

<h1>Cache Cleared</h1>
<p>All application caches have been cleared. The components will be recompiled on next request.</p>
<p><a href="/dir/admin/users/index.cfm">Go to Users Page</a></p>
