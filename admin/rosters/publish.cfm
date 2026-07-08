<!---
    Publish an existing generated roster PDF to Dropbox.
    Permission: rosters.manage.
--->

<cfsetting showdebugoutput="false">

<cfif NOT request.hasPermission("rosters.manage")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<cfif cgi.request_method NEQ "POST">
    <cflocation url="index.cfm" addtoken="false">
</cfif>

<cfset appConfigService = createObject("component", "cfc.appConfig_service").init()>
<cfset redirectURL = "index.cfm">
<cfset requestedFileName = trim(form.filename ?: "")>
<cfset publishStatus = "fail">
<cfset publishPath = "">
<cfset publishError = "Dropbox publish failed.">
<cfset rosterDirectory = expandPath("/_temp_rosters")>
<cfset publishMetaPath = rosterDirectory & "/.publish-status.json">

<cftry>
    <cfif NOT len(requestedFileName) OR NOT reFindNoCase("^class-of-[0-9]{4}-roster\.pdf$", requestedFileName)>
        <cfthrow type="Roster.InvalidInput" message="Invalid roster file name.">
    </cfif>

    <cfif NOT listFindNoCase("1,true,yes,on", lCase(trim(appConfigService.getValue("roster.dropbox_publish_enabled", "false"))))>
        <cfthrow type="Roster.DropboxDisabled" message="Dropbox publishing is disabled for rosters.">
    </cfif>

    <cfset localFilePath = expandPath("/_temp_rosters/#requestedFileName#")>
    <cfif NOT fileExists(localFilePath)>
        <cfthrow type="Roster.FileMissing" message="Requested roster file does not exist.">
    </cfif>

    <cfset publishFolder = trim(appConfigService.getValue("roster.dropbox_publish_path", "Digital Assets/MyUHCO"))>
    <cfset dropboxProvider = createObject("component", "cfc.DropboxProvider").init()>

    <cfif len(publishFolder)>
        <cfset dropboxProvider.createFolder(publishFolder)>
    </cfif>

    <cfset publishPath = dropboxProvider.uploadFile(
        localPath = localFilePath,
        dropboxPath = publishFolder & "/" & requestedFileName,
        overwrite = true
    )>
    <cfset publishStatus = "ok">
    <cfset publishError = "">

    <cfset redirectURL &= "?msg=" & urlEncodedFormat("Roster published to Dropbox.")>
    <cfset redirectURL &= "&publish=ok">
    <cfset redirectURL &= "&publishPath=" & urlEncodedFormat(publishPath)>
<cfcatch>
    <cfset publishStatus = "fail">
    <cfset publishError = left(trim(cfcatch.message ?: "Dropbox publish failed."), 240)>
    <cfset redirectURL &= "?publish=fail">
    <cfset redirectURL &= "&publishErr=" & urlEncodedFormat(publishError)>
</cfcatch>
</cftry>

<cfif len(requestedFileName)>
    <cftry>
        <cflock type="exclusive" timeout="5" name="roster.publishmeta.#hash(publishMetaPath)#">
            <cfset publishMeta = {}>
            <cfif fileExists(publishMetaPath)>
                <cfset publishMetaRaw = trim(fileRead(publishMetaPath, "utf-8"))>
                <cfif len(publishMetaRaw) AND isJSON(publishMetaRaw)>
                    <cfset publishMeta = deserializeJSON(publishMetaRaw)>
                    <cfif NOT isStruct(publishMeta)>
                        <cfset publishMeta = {}>
                    </cfif>
                </cfif>
            </cfif>

            <cfset publishMeta[lCase(requestedFileName)] = {
                "lastStatus" = publishStatus,
                "lastAttemptAt" = dateTimeFormat(now(), "mm/dd/yyyy h:nn tt"),
                "lastPublishedAt" = publishStatus EQ "ok" ? dateTimeFormat(now(), "mm/dd/yyyy h:nn tt") : "",
                "lastPublishedPath" = publishStatus EQ "ok" ? publishPath : "",
                "lastError" = publishStatus EQ "fail" ? publishError : ""
            }>

            <cfset fileWrite(publishMetaPath, serializeJSON(publishMeta), "utf-8")>
        </cflock>
    <cfcatch>
        <!--- Keep publish response non-blocking if metadata write fails. --->
    </cfcatch>
    </cftry>
</cfif>

<cflocation url="#redirectURL#" addtoken="false">