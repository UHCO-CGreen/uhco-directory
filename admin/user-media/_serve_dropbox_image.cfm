<!---
    _serve_dropbox_image.cfm
    Proxy endpoint: downloads a Dropbox image and streams it to the browser.
    Used by crop.cfm and resize.cfm to display source images from Dropbox.

    URL params:
        path  - Dropbox path to the image (e.g. /Digital Assets/Headshots/photo.jpg)
--->
<cfif NOT request.hasPermission("media.edit")>
    <cfheader statuscode="403">
    <cfabort>
</cfif>

<cfset dropboxPath = trim(url.path ?: "")>

<cfif NOT len(dropboxPath)>
    <cfheader statuscode="400">
    <cfabort>
</cfif>

<!--- Validate it looks like a file path (must not be a folder, must have extension) --->
<cfset ext = lCase(listLast(dropboxPath, "."))>
<cfif NOT listFindNoCase("jpg,jpeg,png,webp", ext)>
    <cfheader statuscode="400">
    <cfabort>
</cfif>

<cfset dropboxProvider = createObject("component", "cfc.DropboxProvider").init()>

<cftry>
    <cfset tempLink = dropboxProvider.getTemporaryLink(dropboxPath)>
    <cflocation url="#tempLink#" addtoken="false" statuscode="302">
    <cfcatch type="any">
        <cfheader statuscode="500">
        <cfoutput>Error: #encodeForHTML(cfcatch.message)#</cfoutput>
        <cfabort>
    </cfcatch>
</cftry>
