<cfset flagsService = createObject("component", "cfc.flags_service").init()>
<cfset allFlagsResult = flagsService.getAllFlags()>
<cfset allFlags = allFlagsResult.data />

<!--- ── Alias Types ── --->
<cfset aliasesSvc  = createObject("component", "cfc.aliases_service").init()>
<cfset aliasTypes  = aliasesSvc.getAliasTypes()>

<!--- ── Grad year flag IDs ── --->
<cfset gradYearFlagIDs = []>
<cfloop from="1" to="#arrayLen(allFlags)#" index="i">
    <cfset flagNameLC = lCase(trim(allFlags[i].FLAGNAME))>
    <cfif flagNameLC EQ "current-student" OR flagNameLC EQ "alumni">
        <cfset arrayAppend(gradYearFlagIDs, allFlags[i].FLAGID)>
    </cfif>
</cfloop>
<cfset organizationsService = createObject("component", "cfc.organizations_service").init()>
<cfset allOrganizationsResult = organizationsService.getAllOrgs()>
<cfset allOrganizations = allOrganizationsResult.data />

<!--- ── External IDs ── --->
<cfset externalIDService = createObject("component", "cfc.externalID_service").init()>
<cfset allSystemsResult  = externalIDService.getSystems()>
<cfset allSystems        = allSystemsResult.data>

<cfset extIDHtml = "<div class='mb-3'><label class='form-label fw-semibold'>External IDs</label><div class='border p-3 rounded'><div class='row g-2'>">
<cfif arrayLen(allSystems) GT 0>
    <cfloop from="1" to="#arrayLen(allSystems)#" index="i">
        <cfset sys = allSystems[i]>
        <cfset extIDHtml &= "<div class='col-md-6 col-lg-4'><label class='form-label form-label-sm text-muted mb-1'>" & EncodeForHTML(sys.SYSTEMNAME) & "</label><input class='form-control form-control-sm' name='extID_" & sys.SYSTEMID & "' placeholder='Not set'></div>">
    </cfloop>
<cfelse>
    <cfset extIDHtml &= "<p class='text-muted mb-0'>No external systems configured.</p>">
</cfif>
<cfset extIDHtml &= "</div></div></div>">
<cfset orgIds = {}>
<cfset orgChildrenByParent = {}>

<cfloop from="1" to="#arrayLen(allOrganizations)#" index="i">
    <cfset org = allOrganizations[i]>
    <cfset orgIds[toString(org.ORGID)] = true>
</cfloop>

<cfloop from="1" to="#arrayLen(allOrganizations)#" index="i">
    <cfset org = allOrganizations[i]>
    <cfset parentValue = trim((org.PARENTORGID ?: "") & "")>
    <cfset parentKey = "ROOT">

    <cfif len(parentValue) AND structKeyExists(orgIds, parentValue)>
        <cfset parentKey = parentValue>
    </cfif>

    <cfif NOT structKeyExists(orgChildrenByParent, parentKey)>
        <cfset orgChildrenByParent[parentKey] = []>
    </cfif>
    <cfset arrayAppend(orgChildrenByParent[parentKey], org)>
</cfloop>

<cffunction name="renderOrgCheckboxTree" access="private" returntype="string" output="false">
    <cfargument name="parentKey" type="string" required="true">
    <cfargument name="depth" type="numeric" required="true">
    <cfargument name="selectedOrgIDs" type="array" required="true">

    <cfset var html = "">
    <cfset var childOrgs = []>
    <cfset var j = 0>
    <cfset var child = {}>
    <cfset var checked = false>
    <cfset var childKey = "">
    <cfset var parentAttr = "">
    <cfset var childDesc = "">

    <cfif NOT structKeyExists(orgChildrenByParent, arguments.parentKey)>
        <cfreturn "">
    </cfif>

    <cfset childOrgs = orgChildrenByParent[arguments.parentKey]>
    <cfset html &= "<ul class='list-unstyled mb-1 users-new-org-tree'>">

    <cfloop from="1" to="#arrayLen(childOrgs)#" index="j">
        <cfset child = childOrgs[j]>
        <cfset checked = arrayFindNoCase(arguments.selectedOrgIDs, val(child.ORGID)) GT 0>
        <cfset childKey = toString(child.ORGID)>
        <cfset parentAttr = arguments.parentKey EQ "ROOT" ? "" : arguments.parentKey>
        <cfset html &= "
            <li class='mb-1'>
                <div class='form-check'>
                    <input class='form-check-input org-checkbox' type='checkbox' name='Organizations' value='#child.ORGID#' id='org#child.ORGID#' data-orgid='#child.ORGID#' data-parentorgid='#parentAttr#' " & (checked ? "checked" : "") & ">
                    <label class='form-check-label' for='org#child.ORGID#'>
                        #EncodeForHTML(child.ORGNAME)#
                    </label>
                </div>
            </li>
        ">
        <!--- Description for root/parent orgs only (depth 0) --->
        <cfif arguments.depth EQ 0>
            <cfset childDesc = trim(child.ORGDESCRIPTION ?: '')>
            <cfif len(childDesc)>
                <cfset html &= "<p class='text-muted small mb-0 ms-4 fst-italic'>#EncodeForHTML(childDesc)#</p>">
            </cfif>
        </cfif>
        <cfset html &= renderOrgCheckboxTree(childKey, arguments.depth + 1, arguments.selectedOrgIDs)>
    </cfloop>

    <cfset html &= "</ul>">
    <cfreturn html>
</cffunction>

<cfset content = "
<h1>Create User</h1>

<form class='mt-4' method='POST' action='/admin/users/saveUser.cfm'>
    <input type='hidden' name='processOrganizations' value='1'>
    <input type='hidden' name='processExternalIDs' value='1'>
    <input type='hidden' name='processAcademicInfo' value='1'>
    <div class='row mb-3'>
        <div class='col-md-4'>
            <label class='form-label'>Prefix</label>
            <input class='form-control' name='Prefix'>
        </div>
        <div class='col-md-4'>
            <label class='form-label'>Suffix</label>
            <input class='form-control' name='Suffix'>
        </div>
        <div class='col-md-4'>
            <label class='form-label'>Pronouns</label>
            <input class='form-control' name='Pronouns'>
        </div>
    </div>
    <div class='row mb-3'>
        <div class='col-md-4'>
            <label class='form-label'>First Name</label>
            <input class='form-control' name='FirstName' required>
        </div>
        <div class='col-md-4'>
            <label class='form-label'>Middle Name</label>
            <input class='form-control' name='MiddleName'>
        </div>
        <div class='col-md-4'>
            <label class='form-label'>Last Name</label>
            <input class='form-control' name='LastName' required>
        </div>
    </div>

    <div class='mb-4'>
        <label class='form-label fw-semibold'>Name Aliases</label>
        <div id='aliasesContainer'>
        </div>
        <input type='hidden' name='alias_count' id='aliasCount' value='0'>
        <input type='hidden' name='processAliases' value='1'>
        <button type='button' class='btn btn-sm btn-outline-primary mt-2' id='addAliasRow'>+ Add Alias</button>
    </div>

    <div class='row mb-3'>
        <div class='col-md-3'>
            <label class='form-label'>Date of Birth</label>
            <input class='form-control' type='date' name='DOB'>
        </div>
        <div class='col-md-3'>
            <label class='form-label'>Gender</label>
            <select class='form-select' name='Gender'>
                <option value=''>--</option>
                <option value='Male'>Male</option>
                <option value='Female'>Female</option>
            </select>
        </div>
    </div>

    <div class='row mb-3'>
        <div class='col-md-6'>
            <label class='form-label'>Degrees</label>
            <input class='form-control' name='Degrees'>
        </div>
    </div>

    <div class='row mb-3'>
        <div class='col-md-6'>
            <label class='form-label'>Email (@uh)</label>
            <input class='form-control' id='emailPrimary' name='EmailPrimary' type='email'>
            <div class='invalid-feedback' id='emailPrimaryErr'></div>
        </div>
    </div>

    <div class='row mb-3'>
        <div class='col-md-6'>
            <label class='form-label'>Phone</label>
            <input class='form-control' name='Phone'>
        </div>
        <div class='col-md-6'>
            <label class='form-label'>UH API ID</label>
            <input class='form-control' name='UH_API_ID'>
        </div>
    </div>

    <div class='row mb-3'>
        <div class='col-md-4'>
            <label class='form-label'>Title 1</label>
            <input class='form-control' name='Title1'>
        </div>
        <div class='col-md-4'>
            <label class='form-label'>Title 2</label>
            <input class='form-control' name='Title2'>
        </div>
        <div class='col-md-4'>
            <label class='form-label'>Title 3</label>
            <input class='form-control' name='Title3'>
        </div>
    </div>
    
    <h5 class='mt-4 mb-3'>Address</h5>
    <div class='row mb-3'>
        <div class='col-md-4'>
            <label class='form-label'>Room</label>
            <input class='form-control' name='Room'>
        </div>
        <div class='col-md-4'>
            <label class='form-label'>Building</label>
            <input class='form-control' name='Building'>
        </div>
    </div>
    <div class='row mb-3'>
        <div class='col-md-4'>
            <label class='form-label'>Campus</label>
            <input class='form-control' name='Campus'>
        </div>
        <div class='col-md-4'>
            <label class='form-label'>Division</label>
            <input class='form-control' name='Division'>
        </div>
        <div class='col-md-4'>
            <label class='form-label'>Division Name</label>
            <input class='form-control' name='DivisionName'>
        </div>
    </div>
    <div class='row mb-3'>
        <div class='col-md-4'>
            <label class='form-label'>Department</label>
            <input class='form-control' name='Department'>
        </div>
        <div class='col-md-4'>
            <label class='form-label'>Department Name</label>
            <input class='form-control' name='DepartmentName'>
        </div>
        <div class='col-md-4'></div>
    </div>
    <div class='row mb-3'>
        <div class='col-md-8'>
            <label class='form-label'>Office Mailing Address</label>
            <input class='form-control' name='Office_Mailing_Address'>
        </div>
        <div class='col-md-4'>
            <label class='form-label'>Mailcode</label>
            <input class='form-control' name='Mailcode'>
        </div>
    </div>

    <div class='row mb-3 d-none' id='gradYearRow'>
        <div class='col-md-6'>
            <label class='form-label'>Current Grad Year</label>
            <input class='form-control' name='CurrentGradYear' id='currentGradYear' placeholder='e.g. 2028'>
        </div>
        <div class='col-md-6'>
            <label class='form-label'>Original Grad Year</label>
            <input class='form-control' name='OriginalGradYear' id='originalGradYear' placeholder='e.g. 2027' disabled>
            <div class='form-text'>Requires a Current Grad Year.</div>
        </div>
    </div>

    <div class='mb-3'>
        <label class='form-label'>Flags</label>
        <div class='border p-3 rounded admin-scroll-panel-xs'>
" />

<cfif arrayLen(allFlags) gt 0>
    <cfloop from="1" to="#arrayLen(allFlags)#" index="i">
        <cfset flag = allFlags[i]>
        <cfset content &= "
            <div class='form-check'>
                <input class='form-check-input' type='checkbox' name='Flags' value='#flag.FLAGID#' id='flag#flag.FLAGID#'>
                <label class='form-check-label' for='flag#flag.FLAGID#'>
                    #flag.FLAGNAME#
                </label>
            </div>
        ">
    </cfloop>
<cfelse>
    <cfset content &= "<p class='text-muted'>No flags available</p>">
</cfif>

<cfset content &= "
        </div>
    </div>

    <div class='mb-3'>
        <label class='form-label'>Organizations</label>
        <div class='border p-3 rounded admin-scroll-panel-xs'>
" />

<cfif arrayLen(allOrganizations) gt 0>
    <cfset content &= renderOrgCheckboxTree("ROOT", 0, [])>
<cfelse>
    <cfset content &= "<p class='text-muted'>No organizations available</p>">
</cfif>

<cfset content &= "
        </div>
    </div>

    <script>
    /* ── Repeatable Alias rows ── */
    (function () {
        var container  = document.getElementById('aliasesContainer');
        var countInput = document.getElementById('aliasCount');
        var addBtn     = document.getElementById('addAliasRow');
        if (!container || !countInput || !addBtn) return;

        var aliasTypeOptions = [<cfoutput>''<cfloop from=""1"" to=""#arrayLen(aliasTypes)#"" index=""local.ati"">,'#jsStringFormat(aliasTypes[local.ati].ALIASTYPECODE)#'</cfloop></cfoutput>];
        var aliasTypeLabels  = [<cfoutput>'-- Type --'<cfloop from=""1"" to=""#arrayLen(aliasTypes)#"" index=""local.ati"">,'#jsStringFormat(aliasTypes[local.ati].DESCRIPTION)#'</cfloop></cfoutput>];

        function reindex() {
            var rows = container.querySelectorAll('.alias-row');
            rows.forEach(function (row, idx) {
                var f = row.querySelector('[data-field=alias_first]');
                var m = row.querySelector('[data-field=alias_middle]');
                var l = row.querySelector('[data-field=alias_last]');
                var t = row.querySelector('[data-field=alias_type]');
                var s = row.querySelector('[data-field=alias_source]');
                var a = row.querySelector('[data-field=alias_active]');
                if (f) f.name = 'alias_first_' + idx;
                if (m) m.name = 'alias_middle_' + idx;
                if (l) l.name = 'alias_last_' + idx;
                if (t) t.name = 'alias_type_' + idx;
                if (s) s.name = 'alias_source_' + idx;
                if (a) a.name = 'alias_active_' + idx;
            });
            countInput.value = rows.length;
        }

        addBtn.addEventListener('click', function () {
            var idx = parseInt(countInput.value, 10);
            var row = document.createElement('div');
            row.className = 'row g-2 mb-2 alias-row';

            var c1 = document.createElement('div'); c1.className = 'col-md-2';
            var inp1 = document.createElement('input');
            inp1.className = 'form-control form-control-sm'; inp1.name = 'alias_first_' + idx;
            inp1.setAttribute('data-field', 'alias_first'); inp1.placeholder = 'First Name';
            c1.appendChild(inp1);

            var c2 = document.createElement('div'); c2.className = 'col-md-2';
            var inp2 = document.createElement('input');
            inp2.className = 'form-control form-control-sm'; inp2.name = 'alias_middle_' + idx;
            inp2.setAttribute('data-field', 'alias_middle'); inp2.placeholder = 'Middle Name';
            c2.appendChild(inp2);

            var c3 = document.createElement('div'); c3.className = 'col-md-2';
            var inp3 = document.createElement('input');
            inp3.className = 'form-control form-control-sm'; inp3.name = 'alias_last_' + idx;
            inp3.setAttribute('data-field', 'alias_last'); inp3.placeholder = 'Last Name';
            c3.appendChild(inp3);

            var c4 = document.createElement('div'); c4.className = 'col-md-2';
            var sel = document.createElement('select');
            sel.className = 'form-select form-select-sm'; sel.name = 'alias_type_' + idx;
            sel.setAttribute('data-field', 'alias_type');
            for (var ti = 0; ti < aliasTypeOptions.length; ti++) {
                var opt = document.createElement('option');
                opt.value = aliasTypeOptions[ti]; opt.textContent = aliasTypeLabels[ti];
                sel.appendChild(opt);
            }
            c4.appendChild(sel);

            var c5 = document.createElement('div'); c5.className = 'col-md-2';
            var inp5 = document.createElement('input');
            inp5.className = 'form-control form-control-sm'; inp5.name = 'alias_source_' + idx;
            inp5.setAttribute('data-field', 'alias_source'); inp5.placeholder = 'Source System';
            c5.appendChild(inp5);

            var c6 = document.createElement('div'); c6.className = 'col-md-1 d-flex align-items-center';
            var chkDiv = document.createElement('div'); chkDiv.className = 'form-check';
            var chk = document.createElement('input');
            chk.className = 'form-check-input'; chk.type = 'checkbox';
            chk.name = 'alias_active_' + idx; chk.value = '1'; chk.checked = true;
            chk.setAttribute('data-field', 'alias_active');
            var lbl = document.createElement('label');
            lbl.className = 'form-check-label small'; lbl.textContent = 'Active';
            chkDiv.appendChild(chk); chkDiv.appendChild(lbl);
            c6.appendChild(chkDiv);

            var c7 = document.createElement('div'); c7.className = 'col-md-1';
            var btn = document.createElement('button');
            btn.type = 'button'; btn.className = 'btn btn-sm btn-outline-danger remove-alias-row w-100';
            btn.textContent = 'Remove';
            btn.addEventListener('click', function () { row.remove(); reindex(); });
            c7.appendChild(btn);

            row.appendChild(c1); row.appendChild(c2); row.appendChild(c3); row.appendChild(c4);
            row.appendChild(c5); row.appendChild(c6); row.appendChild(c7);
            container.appendChild(row);
            countInput.value = idx + 1;
        });
    })();
    </script>

    <script>
    (function () {
        var orgCheckboxes = Array.prototype.slice.call(document.querySelectorAll(""input.org-checkbox[name='Organizations']""));
        if (!orgCheckboxes.length) {
            return;
        }

        var byOrgId = {};
        var childrenByParent = {};

        orgCheckboxes.forEach(function (cb) {
            var orgId = cb.getAttribute(""data-orgid"") || """";
            var parentId = cb.getAttribute(""data-parentorgid"") || """";

            byOrgId[orgId] = cb;
            if (!childrenByParent[parentId]) {
                childrenByParent[parentId] = [];
            }
            childrenByParent[parentId].push(cb);
        });

        function checkAncestors(cb) {
            var parentId = cb.getAttribute(""data-parentorgid"") || """";
            while (parentId && byOrgId[parentId]) {
                byOrgId[parentId].checked = true;
                parentId = byOrgId[parentId].getAttribute(""data-parentorgid"") || """";
            }
        }

        function hasAnyCheckedDescendant(orgId) {
            var stack = (childrenByParent[orgId] || []).slice();
            while (stack.length) {
                var child = stack.pop();
                if (child.checked) {
                    return true;
                }
                var childId = child.getAttribute(""data-orgid"") || """";
                var grandChildren = childrenByParent[childId] || [];
                for (var i = 0; i < grandChildren.length; i++) {
                    stack.push(grandChildren[i]);
                }
            }
            return false;
        }

        function uncheckAncestorsIfNoCheckedChildren(cb) {
            var parentId = cb.getAttribute(""data-parentorgid"") || """";
            while (parentId && byOrgId[parentId]) {
                if (!hasAnyCheckedDescendant(parentId)) {
                    byOrgId[parentId].checked = false;
                }
                parentId = byOrgId[parentId].getAttribute(""data-parentorgid"") || """";
            }
        }

        orgCheckboxes.forEach(function (cb) {
            if (cb.checked) {
                checkAncestors(cb);
            }

            cb.addEventListener(""change"", function () {
                if (cb.checked) {
                    checkAncestors(cb);
                } else {
                    uncheckAncestorsIfNoCheckedChildren(cb);
                }
            });
        });
    })();
    </script>

    <script>
    (function () {
        var gradYearFlagIDs = [#arrayToList(gradYearFlagIDs)#];
        var row  = document.getElementById('gradYearRow');
        var curr = document.getElementById('currentGradYear');
        var orig = document.getElementById('originalGradYear');

        function syncOriginal() {
            if (!curr || !orig) return;
            var hasValue = curr.value.trim().length > 0;
            orig.disabled = !hasValue;
            if (!hasValue) orig.value = '';
        }

        function isAnyGradFlagChecked() {
            return gradYearFlagIDs.some(function (id) {
                var cb = document.querySelector('input[name=""Flags""][value=""' + id + '""]');
                return cb && cb.checked;
            });
        }

        function syncRowVisibility() {
            if (!row) return;
            if (isAnyGradFlagChecked()) {
                row.classList.remove('d-none');
            } else {
                row.classList.add('d-none');
                if (curr) curr.value = '';
                if (orig) { orig.value = ''; orig.disabled = true; }
            }
        }

        if (curr) curr.addEventListener('input', syncOriginal);

        gradYearFlagIDs.forEach(function (id) {
            var cb = document.querySelector('input[name=""Flags""][value=""' + id + '""]');
            if (cb) cb.addEventListener('change', syncRowVisibility);
        });
    })();
    </script>

    <script>
    (function () {
        var epEl  = document.getElementById('emailPrimary');
        var epErr = document.getElementById('emailPrimaryErr');
        function showError(el, errEl, msg) { el.classList.add('is-invalid'); errEl.textContent = msg; }
        function clearError(el, errEl)     { el.classList.remove('is-invalid'); errEl.textContent = ''; }
        function validatePrimary() {
            var val = (epEl ? epEl.value : '').trim().toLowerCase();
            if (val && !val.endsWith('@uh.edu')) {
                showError(epEl, epErr, 'Must be a @uh.edu address (e.g. jsmith@uh.edu).');
                return false;
            }
            if (epEl) clearError(epEl, epErr);
            return true;
        }
        if (epEl) epEl.addEventListener('blur', validatePrimary);
        var form = epEl ? epEl.closest('form') : null;
        if (form) {
            form.addEventListener('submit', function (e) {
                if (!validatePrimary()) { e.preventDefault(); var inv = document.querySelector('.is-invalid'); if (inv) inv.focus(); }
            });
        }
    })();
    </script>

    #extIDHtml#

    <button class='btn btn-success'>Save User</button>
    <a href='/admin/users/index.cfm' class='btn btn-secondary'>Cancel</a>
</form>
" />

<cfinclude template="/admin/layout.cfm">