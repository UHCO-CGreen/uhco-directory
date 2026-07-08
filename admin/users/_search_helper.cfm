<!---
    _search_helper.cfm
    Defines userMatchesSearch(u, searchTerm) for user-list pages.

    Supported syntax:
      Plain text          → contains match on firstname, lastname, or either email
      "value"             → exact match on any field  (e.g. "Ha")
      field:value         → contains match on a specific field  (e.g. lastname:Ha)
      field:"value"       → exact match on a specific field     (e.g. lastname:"Ha")
      field:(value)       → exact match on a specific field     (e.g. lastname:(Ha))
      term1 && term2      → both conditions must match (AND)
      term1 || term2      → either condition must match (OR)

    Supported field names (case-insensitive):
      firstname, lastname, email, primaryemail / emailprimary, title
--->
<cffunction name="userMatchesSearch" returntype="boolean" output="false">
    <cfargument name="u"          type="struct" required="true">
    <cfargument name="searchTerm" type="string" required="true">

    <cfset var st = trim(arguments.searchTerm)>
  <cfset var firstName = _userSearchGetValue(arguments.u, "FIRSTNAME,FirstName,firstName")>
  <cfset var lastName = _userSearchGetValue(arguments.u, "LASTNAME,LastName,lastName")>
  <cfset var primaryEmail = _userSearchGetValue(arguments.u, "EMAILPRIMARY,EmailPrimary,emailPrimary,EMAIL,Email,email")>
  <cfset var preferredName = _userSearchGetValue(arguments.u, "PREFERREDNAME,PreferredName,preferredName,DISPLAYNAME,DisplayName,displayName")>
  <cfset var titleValue = _userSearchGetValue(arguments.u, "TITLE1,Title1,title1,TITLE,Title,title")>
    <cfif NOT len(st)><cfreturn true></cfif>

    <!--- Split on || → OR groups (use chr(30) as safe interim delimiter) --->
    <cfset var orParts = listToArray(replace(st, "||", chr(30), "all"), chr(30))>

    <cfset var oi          = 0>
    <cfset var ai          = 0>
    <cfset var orPart      = "">
    <cfset var andParts    = []>
    <cfset var cond        = "">
    <cfset var colonPos    = 0>
    <cfset var fieldName   = "">
    <cfset var fieldVal    = "">
    <cfset var exactMatch  = false>
    <cfset var andMatch    = false>
    <cfset var condMatches = false>

    <cfloop from="1" to="#arrayLen(orParts)#" index="oi">
        <cfset orPart = trim(orParts[oi])>
        <cfif NOT len(orPart)><cfcontinue></cfif>

        <!--- Split on && → AND conditions --->
        <cfset andParts = listToArray(replace(orPart, "&&", chr(31), "all"), chr(31))>
        <cfset andMatch = true>

        <cfloop from="1" to="#arrayLen(andParts)#" index="ai">
            <cfset cond = trim(andParts[ai])>
            <cfif NOT len(cond)><cfcontinue></cfif>

            <cfset colonPos = find(":", cond)>

            <cfif colonPos GT 1>
                <!--- field:value operator --->
                <cfset fieldName  = lCase(trim(left(cond, colonPos - 1)))>
                <cfset fieldVal   = trim(mid(cond, colonPos + 1, len(cond)))>

                <!--- Detect exact-match wrappers: "value" or (value) --->
                <cfset exactMatch = false>
                <cfif (left(fieldVal,1) EQ '"'  AND right(fieldVal,1) EQ '"')  OR
                      (left(fieldVal,1) EQ "("  AND right(fieldVal,1) EQ ")")>
                    <cfset exactMatch = true>
                    <cfset fieldVal   = trim(mid(fieldVal, 2, len(fieldVal) - 2))>
                </cfif>

                <cfset condMatches = false>
                <cfif fieldName EQ "firstname">
                  <cfset condMatches = exactMatch
                    ? _userSearchEquals(firstName, fieldVal)
                    : _userSearchContains(firstName, fieldVal)>
                <cfelseif fieldName EQ "lastname">
                  <cfset condMatches = exactMatch
                    ? _userSearchEquals(lastName, fieldVal)
                    : _userSearchContains(lastName, fieldVal)>
                <cfelseif fieldName EQ "emailprimary" OR fieldName EQ "primaryemail">
                  <cfset condMatches = exactMatch
                    ? _userSearchEquals(primaryEmail, fieldVal)
                    : _userSearchContains(primaryEmail, fieldVal)>
                <cfelseif fieldName EQ "email">
                    <cfif exactMatch>
                    <cfset condMatches = _userSearchEquals(primaryEmail, fieldVal)>
                    <cfelse>
                    <cfset condMatches = _userSearchContains(primaryEmail, fieldVal)>
                    </cfif>
                <cfelseif fieldName EQ "title">
                  <cfset condMatches = exactMatch
                    ? _userSearchEquals(titleValue, fieldVal)
                    : _userSearchContains(titleValue, fieldVal)>
                <cfelseif fieldName EQ "flags" OR fieldName EQ "flag">
                  <cfset condMatches = _userSearchContains(_userSearchGetValue(arguments.u, "SEARCH_FLAGS"), fieldVal)>
                <cfelseif fieldName EQ "orgs" OR fieldName EQ "org">
                  <cfset condMatches = _userSearchContains(_userSearchGetValue(arguments.u, "SEARCH_ORGS"), fieldVal)>
                <cfelseif fieldName EQ "phone">
                  <cfset condMatches = exactMatch
                    ? _userSearchEquals(_userSearchGetValue(arguments.u, "SEARCH_PHONE"), fieldVal)
                    : _userSearchContains(_userSearchGetValue(arguments.u, "SEARCH_PHONE"), fieldVal)>
                <cfelseif fieldName EQ "cougarnet">
                  <cfset condMatches = exactMatch
                    ? _userSearchEquals(_userSearchGetValue(arguments.u, "SEARCH_COUGARNET"), fieldVal)
                    : _userSearchContains(_userSearchGetValue(arguments.u, "SEARCH_COUGARNET"), fieldVal)>
                <cfelseif fieldName EQ "psid" OR fieldName EQ "peoplesoft">
                  <cfset condMatches = exactMatch
                    ? _userSearchEquals(_userSearchGetValue(arguments.u, "SEARCH_PSID"), fieldVal)
                    : _userSearchContains(_userSearchGetValue(arguments.u, "SEARCH_PSID"), fieldVal)>
                <cfelseif fieldName EQ "gradyear" OR fieldName EQ "grad">
                  <cfset condMatches = _userSearchContains(_userSearchGetValue(arguments.u, "SEARCH_GRADYEARS"), fieldVal)>
                <cfelse>
                    <!--- Unknown field: fall back to any-field match on the full original token --->
                  <cfset condMatches = _userSearchContains(firstName, cond) OR
                             _userSearchContains(lastName, cond) OR
                             _userSearchContains(primaryEmail, cond) OR
                             _userSearchContains(preferredName, cond)>
                </cfif>

            <cfelse>
                <!--- Plain text: detect exact-match wrappers --->
                <cfset exactMatch = false>
                <cfif (left(cond,1) EQ '"'  AND right(cond,1) EQ '"')  OR
                      (left(cond,1) EQ "("  AND right(cond,1) EQ ")")>
                    <cfset exactMatch = true>
                    <cfset cond = trim(mid(cond, 2, len(cond) - 2))>
                </cfif>

                <cfif exactMatch>
                  <cfset condMatches = _userSearchEquals(firstName, cond) OR
                             _userSearchEquals(lastName, cond) OR
                             _userSearchEquals(primaryEmail, cond) OR
                             _userSearchEquals(preferredName, cond)>
                <cfelse>
                  <cfset condMatches = _userSearchContains(firstName, cond) OR
                             _userSearchContains(lastName, cond) OR
                             _userSearchContains(primaryEmail, cond) OR
                             _userSearchContains(preferredName, cond)>
                  <!--- Also detect "Firstname Lastname" and "Lastname, Firstname" name patterns --->
                  <cfif NOT condMatches>
                    <cfset nameCommaPos = find(",", cond)>
                    <cfif nameCommaPos GT 1>
                      <!--- "Lastname, Firstname" pattern --->
                      <cfset nameLN = trim(left(cond, nameCommaPos - 1))>
                      <cfset nameFN = trim(mid(cond, nameCommaPos + 1, len(cond)))>
                      <cfif len(nameLN) AND len(nameFN)>
                        <cfset condMatches = (_userSearchContains(firstName, nameFN) AND _userSearchContains(lastName, nameLN)) OR
                                             (_userSearchContains(preferredName, nameFN) AND _userSearchContains(lastName, nameLN))>
                      </cfif>
                    <cfelseif find(" ", cond) GT 0>
                      <!--- "Firstname Lastname" pattern --->
                      <cfset nameSpacePos = find(" ", cond)>
                      <cfset nameFN = trim(left(cond, nameSpacePos - 1))>
                      <cfset nameLN = trim(mid(cond, nameSpacePos + 1, len(cond)))>
                      <cfif len(nameFN) AND len(nameLN)>
                        <cfset condMatches = (_userSearchContains(firstName, nameFN) AND _userSearchContains(lastName, nameLN)) OR
                                             (_userSearchContains(preferredName, nameFN) AND _userSearchContains(lastName, nameLN))>
                      </cfif>
                    </cfif>
                  </cfif>
                </cfif>
            </cfif>

            <cfif NOT condMatches>
                <cfset andMatch = false>
                <cfbreak>
            </cfif>
        </cfloop>

        <cfif andMatch>
            <cfreturn true>
        </cfif>
    </cfloop>

    <cfreturn false>
</cffunction>

<cffunction name="_userSearchGetValue" returntype="string" output="false">
  <cfargument name="u" type="struct" required="true">
  <cfargument name="keyList" type="string" required="true">

  <cfset var keyName = "">
  <cfset var rawValue = "">

  <cfloop list="#arguments.keyList#" index="keyName">
    <cfif structKeyExists(arguments.u, keyName)>
      <cfset rawValue = arguments.u[keyName]>
      <cfif isNull(rawValue)>
        <cfreturn "">
      </cfif>
      <cfif isSimpleValue(rawValue)>
        <cfreturn trim(toString(rawValue))>
      </cfif>
      <cfreturn trim(serializeJSON(rawValue))>
    </cfif>
  </cfloop>

  <cfreturn "">
</cffunction>

<cffunction name="_userSearchContains" returntype="boolean" output="false">
  <cfargument name="haystack" type="string" required="true">
  <cfargument name="needle" type="string" required="true">

  <cfif NOT len(trim(arguments.needle))>
    <cfreturn false>
  </cfif>

  <cfreturn findNoCase(trim(arguments.needle), arguments.haystack) GT 0>
</cffunction>

<cffunction name="_userSearchEquals" returntype="boolean" output="false">
  <cfargument name="leftValue" type="string" required="true">
  <cfargument name="rightValue" type="string" required="true">

  <cfreturn compareNoCase(trim(arguments.leftValue), trim(arguments.rightValue)) EQ 0>
</cffunction>

<!--- ── Search help modal (rendered once per page via cfinclude) ── --->
<div class="modal fade" id="searchHelpModal" tabindex="-1" aria-labelledby="searchHelpModalLabel" aria-hidden="true">
  <div class="modal-dialog modal-lg">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title" id="searchHelpModalLabel"><i class="bi bi-search me-2"></i>Search Syntax Reference</h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
      </div>
      <div class="modal-body">

        <h6 class="fw-bold">Basic Search</h6>
        <p class="text-muted small mb-2">Type any text to search across first name, last name, and both email fields.</p>
        <table class="table table-sm table-bordered mb-4">
          <thead class="table-light"><tr><th>Query</th><th>Matches</th></tr></thead>
          <tbody>
            <tr><td><code>Jane</code></td><td>Any record containing "Jane" in name or email</td></tr>
          </tbody>
        </table>

        <h6 class="fw-bold">Basic Name Search</h6>
        <p class="text-muted small mb-2">You can search by full name in either order — no field prefix needed.</p>
        <table class="table table-sm table-bordered mb-4">
          <thead class="table-light"><tr><th>Query</th><th>Matches</th></tr></thead>
          <tbody>
            <tr><td><code>Chris Green</code></td><td>First name contains "Chris" AND last name contains "Green"</td></tr>
            <tr><td><code>Green, Chris</code></td><td>Last name contains "Green" AND first name contains "Chris"</td></tr>
          </tbody>
        </table>

        <h6 class="fw-bold">Field Operators</h6>
        <p class="text-muted small mb-2">Target a specific field with <code>field:value</code>. Performs a <em>contains</em> search.</p>
        <table class="table table-sm table-bordered mb-4">
          <thead class="table-light"><tr><th>Query</th><th>Matches</th></tr></thead>
          <tbody>
            <tr><td><code>lastname:Doe</code></td><td>Last name contains "Doe"</td></tr>
            <tr><td><code>firstname:Jane</code></td><td>First name contains "Jane"</td></tr>
            <tr><td><code>email:uh.edu</code></td><td>Email contains "uh.edu"</td></tr>
            <tr><td><code>phone:713</code></td><td>Phone number contains "713"</td></tr>
            <tr><td><code>cougarnet:jdoe</code></td><td>CougarNet ID contains "jdoe"</td></tr>
            <tr><td><code>psid:12345</code></td><td>PeopleSoft ID contains "12345"</td></tr>
            <tr><td><code>flags:Alumni</code></td><td>Has a flag whose name contains "Alumni"</td></tr>
            <tr><td><code>orgs:Clinic</code></td><td>Belongs to an org whose name contains "Clinic"</td></tr>
            <tr><td><code>gradyear:2024</code></td><td>Has grad year containing "2024"</td></tr>
            <tr><td><code>title:Professor</code></td><td>Title contains "Professor"</td></tr>
          </tbody>
        </table>

        <h6 class="fw-bold">Exact Match</h6>
        <p class="text-muted small mb-2">Wrap the value in <code>"quotes"</code> or <code>(parentheses)</code> to require an exact match (case-insensitive).</p>
        <table class="table table-sm table-bordered mb-4">
          <thead class="table-light"><tr><th>Query</th><th>Matches</th></tr></thead>
          <tbody>
            <tr><td><code>lastname:"Ha"</code></td><td>Last name is exactly "Ha" — not "Ham", "Shah", etc.</td></tr>
            <tr><td><code>lastname:(Ha)</code></td><td>Same as above</td></tr>
            <tr><td><code>"Ha"</code></td><td>Any field is exactly "Ha"</td></tr>
          </tbody>
        </table>

        <h6 class="fw-bold">AND / OR Operators</h6>
        <p class="text-muted small mb-2">Combine conditions with <code>&amp;&amp;</code> (AND) or <code>||</code> (OR).</p>
        <table class="table table-sm table-bordered mb-0">
          <thead class="table-light"><tr><th>Query</th><th>Matches</th></tr></thead>
          <tbody>
            <tr><td><code>firstname:Jane &amp;&amp; lastname:Doe</code></td><td>First name contains "Jane" AND last name contains "Doe"</td></tr>
            <tr><td><code>firstname:"Jane" &amp;&amp; lastname:"Doe"</code></td><td>First name is exactly "Jane" AND last name is exactly "Doe"</td></tr>
            <tr><td><code>firstname:Jane || firstname:John</code></td><td>First name contains "Jane" OR "John"</td></tr>
            <tr><td><code>lastname:"Ha" || lastname:"Ho"</code></td><td>Last name is exactly "Ha" OR exactly "Ho"</td></tr>
          </tbody>
        </table>

      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-ui-cancel" data-bs-dismiss="modal">Close</button>
      </div>
    </div>
  </div>
</div>
