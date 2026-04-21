<!---
    Query Builder — Visual read-only SELECT query builder.
    Permission: settings.query_builder.use. Tables and columns validated against INFORMATION_SCHEMA.
--->

<cfif NOT request.hasPermission("settings.query_builder.use")>
    <cflocation url="#request.webRoot#/admin/unauthorized.cfm" addtoken="false">
</cfif>

<!--- ── Load table list ── --->
<cfset qbService = createObject("component", "cfc.queryBuilder_service").init()>
<cfset tables = []>
<cfset tableError = "">
<cftry>
    <cfset tables = qbService.getTableList()>
<cfcatch>
    <cfset tableError = cfcatch.message>
</cfcatch>
</cftry>

<!--- ── Handle AJAX column request ── --->
<cfif structKeyExists(url, "ajax") AND url.ajax EQ "columns" AND structKeyExists(url, "table")>
    <cfsetting showdebugoutput="false">
    <cfset ajaxResult = { columns = [], error = "" }>
    <cftry>
        <cfset ajaxResult.columns = qbService.getColumnsForTable(trim(url.table))>
    <cfcatch>
        <cfset ajaxResult.error = cfcatch.message>
    </cfcatch>
    </cftry>
    <cfcontent type="application/json" reset="true"><cfoutput>#serializeJSON(ajaxResult)#</cfoutput><cfabort>
</cfif>

<!--- ── Handle AJAX query execution ── --->
<cfif structKeyExists(url, "ajax") AND url.ajax EQ "execute" AND cgi.request_method EQ "POST">
    <cfsetting showdebugoutput="false">
    <cfset execResult = { success = false, sql = "", rows = [], columns = [], rowCount = 0, truncated = false, error = "" }>
    <cftry>
        <cfset body = deserializeJSON(toString(getHTTPRequestData().content))>
        <cfset qResult = qbService.executeQuery(
            tableName  = trim(body.tableName ?: ""),
            columns    = body.columns ?: [],
            conditions = body.conditions ?: [],
            orderBy    = body.orderBy ?: [],
            maxRows    = val(body.maxRows ?: 1000)
        )>
        <cfset execResult.success   = true>
        <cfset execResult.sql       = qResult.sql>
        <cfset execResult.rowCount  = qResult.rowCount>
        <cfset execResult.truncated = qResult.truncated>
        <cfset execResult.columns   = listToArray(qResult.results.columnList)>
        <!--- Convert query to array of arrays for compact JSON --->
        <cfset resultRows = []>
        <cfset colList = qResult.results.columnList>
        <cfloop from="1" to="#qResult.results.recordCount#" index="rowIdx">
            <cfset thisRow = []>
            <cfloop list="#colList#" index="colName">
                <cfset cellVal = qResult.results[colName][rowIdx]>
                <cfset arrayAppend(thisRow, isNull(cellVal) ? "" : cellVal)>
            </cfloop>
            <cfset arrayAppend(resultRows, thisRow)>
        </cfloop>
        <cfset execResult.rows = resultRows>
    <cfcatch>
        <cfset execResult.error = cfcatch.message>
    </cfcatch>
    </cftry>
    <cfcontent type="application/json" reset="true"><cfoutput>#serializeJSON(execResult)#</cfoutput><cfabort>
</cfif>

<!--- ══════════════════════════════════════════════════════════════ --->
<!--- ── Page content ────────────────────────────────────────────── --->
<!--- ══════════════════════════════════════════════════════════════ --->
<cfset content = "">
<cfsavecontent variable="content">
<cfoutput>

<div class="settings-page settings-query-builder">
<nav aria-label="breadcrumb" class="mb-3">
    <ol class="breadcrumb">
        <li class="breadcrumb-item"><a href="/admin/settings/">Settings</a></li>
        <li class="breadcrumb-item active" aria-current="page">Query Builder</li>
    </ol>
</nav>

<div class="d-flex justify-content-between align-items-center mb-4">
    <div>
        <h1 class="mb-1"><i class="bi bi-database me-2"></i>Query Builder</h1>
        <p class="text-muted mb-0">Build read-only SELECT queries visually. Results capped at 10,000 rows. Exportable to CSV (Planned: XML, Excel)</p>
    </div>
    <span class='badge bg-warning text-dark float-end'>Currently in: Alpha</span>
</div>

<cfif len(tableError)>
    <div class="alert alert-danger">#encodeForHTML(tableError)#</div>
</cfif>

<!--- ── Builder Card ── --->
<div class="card shadow-sm mb-4 settings-shell settings-builder-shell">
    <div class="card-header">
        <h5 class="mb-0"><i class="bi bi-tools me-2"></i>Build Query</h5>
    </div>
    <div class="card-body">

        <!--- Table selection --->
        <div class="row g-3 mb-3">
            <div class="col-md-4">
                <label class="form-label fw-semibold">Table <span class="text-danger">*</span></label>
                <select id="qbTable" class="form-select">
                    <option value="">— Select a table —</option>
                    <cfloop from="1" to="#arrayLen(tables)#" index="i">
                        <option value="#encodeForHTMLAttribute(tables[i])#">#encodeForHTML(tables[i])#</option>
                    </cfloop>
                </select>
            </div>
            <div class="col-md-2">
                <label class="form-label fw-semibold">Max Rows</label>
                <input type="number" id="qbMaxRows" class="form-control" value="1000" min="1" max="10000">
            </div>
        </div>

        <!--- Columns --->
        <div class="mb-3 admin-hidden" id="columnsSection">
            <label class="form-label fw-semibold">Columns</label>
            <div class="mb-2">
                <button type="button" class="btn btn-sm btn-outline-secondary" id="btnSelectAll">Select All</button>
                <button type="button" class="btn btn-sm btn-outline-secondary" id="btnSelectNone">Select None</button>
            </div>
            <div id="columnCheckboxes" class="d-flex flex-wrap gap-2"></div>
        </div>

        <!--- WHERE conditions --->
        <div class="mb-3 admin-hidden" id="conditionsSection">
            <label class="form-label fw-semibold">
                WHERE Conditions
                <button type="button" class="btn btn-sm btn-outline-primary ms-2" id="btnAddCondition">
                    <i class="bi bi-plus"></i> Add
                </button>
            </label>
            <div id="conditionRows"></div>
        </div>

        <!--- ORDER BY --->
        <div class="mb-3 admin-hidden" id="orderSection">
            <label class="form-label fw-semibold">
                ORDER BY
                <button type="button" class="btn btn-sm btn-outline-primary ms-2" id="btnAddOrder">
                    <i class="bi bi-plus"></i> Add
                </button>
            </label>
            <div id="orderRows"></div>
        </div>

        <!--- SQL preview --->
        <div class="mb-3 admin-hidden" id="sqlPreviewSection">
            <label class="form-label fw-semibold">SQL Preview</label>
            <pre id="sqlPreview" class="settings-query-preview p-3 mb-0 font-monospace small"></pre>
        </div>

        <!--- Execute button --->
        <div class="d-flex gap-2 admin-hidden" id="executeSection">
            <button type="button" class="btn btn-primary" id="btnExecute">
                <i class="bi bi-play-fill me-1"></i> Execute Query
            </button>
            <button type="button" class="btn btn-outline-secondary admin-hidden" id="btnExportCsv">
                <i class="bi bi-filetype-csv me-1"></i> Export CSV
            </button>
        </div>

    </div>
</div>

<!--- ── Results Card ── --->
<div class="card shadow-sm mb-4 admin-hidden settings-shell settings-results-shell" id="resultsCard">
    <div class="card-header d-flex justify-content-between align-items-center">
        <h5 class="mb-0"><i class="bi bi-table me-2"></i>Results</h5>
        <span id="resultsMeta" class="text-muted small"></span>
    </div>
    <div class="card-body p-0">
        <div class="table-responsive admin-scroll-panel">
            <table class="table table-sm table-striped table-hover align-middle mb-0 settings-table" id="resultsTable">
                <thead id="resultsHead"></thead>
                <tbody id="resultsBody"></tbody>
            </table>
        </div>
    </div>
</div>

<!--- ── Loading spinner --->
<div id="loadingOverlay" class="text-center py-4 admin-hidden settings-query-loading">
    <div class="spinner-border text-primary" role="status"></div>
    <p class="text-muted mt-2">Running query...</p>
</div>

</div>

</cfoutput>
</cfsavecontent>

<!--- ── Page scripts ── --->
<cfset pageScripts = "">
<cfsavecontent variable="pageScripts">
<script>
(function () {
    'use strict';

    // ── State ──
    var allColumns = [];
    var lastResult = null;

    var $table       = document.getElementById('qbTable');
    var $maxRows     = document.getElementById('qbMaxRows');
    var $colSection  = document.getElementById('columnsSection');
    var $colBoxes    = document.getElementById('columnCheckboxes');
    var $condSection = document.getElementById('conditionsSection');
    var $condRows    = document.getElementById('conditionRows');
    var $orderSection= document.getElementById('orderSection');
    var $orderRows   = document.getElementById('orderRows');
    var $sqlSection  = document.getElementById('sqlPreviewSection');
    var $sqlPreview  = document.getElementById('sqlPreview');
    var $execSection = document.getElementById('executeSection');
    var $btnExecute  = document.getElementById('btnExecute');
    var $btnExportCsv= document.getElementById('btnExportCsv');
    var $resultsCard = document.getElementById('resultsCard');
    var $resultsMeta = document.getElementById('resultsMeta');
    var $resultsHead = document.getElementById('resultsHead');
    var $resultsBody = document.getElementById('resultsBody');
    var $loading     = document.getElementById('loadingOverlay');

    var operators = ['=', '!=', '>', '>=', '<', '<=', 'LIKE', 'IN', 'IS NULL', 'IS NOT NULL'];
    var noValueOps = ['IS NULL', 'IS NOT NULL'];

    // Normalize CF uppercase JSON keys to lowercase
    function lowerKeys(obj) {
        if (Array.isArray(obj)) return obj.map(lowerKeys);
        if (obj !== null && typeof obj === 'object') {
            var out = {};
            Object.keys(obj).forEach(function(k){ out[k.toLowerCase()] = lowerKeys(obj[k]); });
            return out;
        }
        return obj;
    }

    // ── Table change → load columns ──
    $table.addEventListener('change', function () {
        allColumns = [];
        $colBoxes.innerHTML = '';
        $condRows.innerHTML = '';
        $orderRows.innerHTML = '';
        hideResults();

        if (!this.value) {
            $colSection.style.display = 'none';
            $condSection.style.display = 'none';
            $orderSection.style.display = 'none';
            $sqlSection.style.display = 'none';
            $execSection.style.display = 'none';
            return;
        }

        fetch('?ajax=columns&table=' + encodeURIComponent(this.value))
            .then(function (r) { return r.json(); })
            .then(function (raw) {
                var data = lowerKeys(raw);
                if (data.error) { alert(data.error); return; }
                allColumns = (data.columns || []).map(function(c){ return lowerKeys(c); });
                renderColumnCheckboxes();
                $colSection.style.display = '';
                $condSection.style.display = '';
                $orderSection.style.display = '';
                $sqlSection.style.display = '';
                $execSection.style.display = '';
                updatePreview();
            });
    });

    // ── Column checkboxes ──
    function renderColumnCheckboxes() {
        $colBoxes.innerHTML = '';
        allColumns.forEach(function (col) {
            var id = 'col_' + col.column_name;
            var div = document.createElement('div');
            div.className = 'form-check';
            div.innerHTML =
                '<input class="form-check-input col-check" type="checkbox" id="' + id + '" value="' + col.column_name + '" checked>' +
                '<label class="form-check-label small" for="' + id + '">' +
                    col.column_name +
                    ' <span class="text-muted">(' + col.data_type +
                    (col.character_maximum_length > 0 ? '(' + col.character_maximum_length + ')' : '') +
                    ')</span>' +
                '</label>';
            $colBoxes.appendChild(div);
            div.querySelector('input').addEventListener('change', updatePreview);
        });
    }

    document.getElementById('btnSelectAll').addEventListener('click', function () {
        document.querySelectorAll('.col-check').forEach(function (cb) { cb.checked = true; });
        updatePreview();
    });
    document.getElementById('btnSelectNone').addEventListener('click', function () {
        document.querySelectorAll('.col-check').forEach(function (cb) { cb.checked = false; });
        updatePreview();
    });

    // ── Condition rows ──
    document.getElementById('btnAddCondition').addEventListener('click', function () {
        addConditionRow();
        updatePreview();
    });

    function addConditionRow() {
        var row = document.createElement('div');
        row.className = 'row g-2 mb-2 cond-row';
        var colOpts = allColumns.map(function (c) {
            return '<option value="' + c.column_name + '">' + c.column_name + '</option>';
        }).join('');
        var opOpts = operators.map(function (o) {
            return '<option value="' + o + '">' + o + '</option>';
        }).join('');
        row.innerHTML =
            '<div class="col-md-3"><select class="form-select form-select-sm cond-col">' + colOpts + '</select></div>' +
            '<div class="col-md-2"><select class="form-select form-select-sm cond-op">' + opOpts + '</select></div>' +
            '<div class="col-md-5"><input type="text" class="form-control form-control-sm cond-val" placeholder="Value"></div>' +
            '<div class="col-md-2"><button type="button" class="btn btn-sm btn-danger users-list-action-button users-list-action-button-delete cond-remove" title="Remove Condition" aria-label="Remove Condition"><i class="bi bi-x"></i></button></div>';
        $condRows.appendChild(row);

        row.querySelector('.cond-col').addEventListener('change', updatePreview);
        row.querySelector('.cond-op').addEventListener('change', function () {
            var valInput = row.querySelector('.cond-val');
            valInput.disabled = noValueOps.indexOf(this.value) >= 0;
            if (valInput.disabled) valInput.value = '';
            updatePreview();
        });
        row.querySelector('.cond-val').addEventListener('input', updatePreview);
        row.querySelector('.cond-remove').addEventListener('click', function () {
            row.remove();
            updatePreview();
        });
    }

    // ── Order rows ──
    document.getElementById('btnAddOrder').addEventListener('click', function () {
        addOrderRow();
        updatePreview();
    });

    function addOrderRow() {
        var row = document.createElement('div');
        row.className = 'row g-2 mb-2 order-row';
        var colOpts = allColumns.map(function (c) {
            return '<option value="' + c.column_name + '">' + c.column_name + '</option>';
        }).join('');
        row.innerHTML =
            '<div class="col-md-4"><select class="form-select form-select-sm order-col">' + colOpts + '</select></div>' +
            '<div class="col-md-3"><select class="form-select form-select-sm order-dir">' +
                '<option value="ASC">ASC</option><option value="DESC">DESC</option></select></div>' +
            '<div class="col-md-2"><button type="button" class="btn btn-sm btn-danger users-list-action-button users-list-action-button-delete order-remove" title="Remove Order By" aria-label="Remove Order By"><i class="bi bi-x"></i></button></div>';
        $orderRows.appendChild(row);

        row.querySelector('.order-col').addEventListener('change', updatePreview);
        row.querySelector('.order-dir').addEventListener('change', updatePreview);
        row.querySelector('.order-remove').addEventListener('click', function () {
            row.remove();
            updatePreview();
        });
    }

    // ── SQL Preview ──
    function getSelectedColumns() {
        var cols = [];
        document.querySelectorAll('.col-check:checked').forEach(function (cb) {
            cols.push(cb.value);
        });
        return cols;
    }

    function getConditions() {
        var conds = [];
        document.querySelectorAll('.cond-row').forEach(function (row) {
            var op = row.querySelector('.cond-op').value;
            var val = row.querySelector('.cond-val').value;
            if (noValueOps.indexOf(op) >= 0 || val.trim() !== '') {
                conds.push({
                    column: row.querySelector('.cond-col').value,
                    operator: op,
                    value: val
                });
            }
        });
        return conds;
    }

    function getOrderBy() {
        var orders = [];
        document.querySelectorAll('.order-row').forEach(function (row) {
            orders.push({
                column: row.querySelector('.order-col').value,
                direction: row.querySelector('.order-dir').value
            });
        });
        return orders;
    }

    function updatePreview() {
        var cols = getSelectedColumns();
        if (!$table.value || cols.length === 0) {
            $sqlPreview.textContent = '-- Select a table and at least one column';
            return;
        }
        var maxR = parseInt($maxRows.value) || 1000;
        if (maxR > 10000) maxR = 10000;

        var sql = 'SELECT TOP ' + maxR + ' [' + cols.join('], [') + ']\nFROM [' + $table.value + ']';
        var conds = getConditions();
        if (conds.length) {
            var parts = conds.map(function (c) {
                if (noValueOps.indexOf(c.operator) >= 0) return '[' + c.column + '] ' + c.operator;
                if (c.operator === 'LIKE') return "[" + c.column + "] LIKE '%" + c.value + "%'";
                if (c.operator === 'IN') return "[" + c.column + "] IN ('" + c.value.split(',').map(function(v){return v.trim()}).join("','") + "')";
                return "[" + c.column + "] " + c.operator + " '" + c.value + "'";
            });
            sql += '\nWHERE ' + parts.join('\n  AND ');
        }
        var orders = getOrderBy();
        if (orders.length) {
            sql += '\nORDER BY ' + orders.map(function (o) { return '[' + o.column + '] ' + o.direction; }).join(', ');
        }
        $sqlPreview.textContent = sql;
    }

    $maxRows.addEventListener('input', updatePreview);

    // ── Execute ──
    $btnExecute.addEventListener('click', function () {
        var cols = getSelectedColumns();
        if (!$table.value || cols.length === 0) {
            alert('Select a table and at least one column.');
            return;
        }
        var payload = {
            tableName:  $table.value,
            columns:    cols,
            conditions: getConditions(),
            orderBy:    getOrderBy(),
            maxRows:    parseInt($maxRows.value) || 1000
        };

        hideResults();
        $loading.style.display = '';
        $btnExecute.disabled = true;

        fetch('?ajax=execute', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        })
        .then(function (r) { return r.json(); })
        .then(function (raw) {
            var data = lowerKeys(raw);
            $loading.style.display = 'none';
            $btnExecute.disabled = false;

            if (data.error) {
                alert('Query error: ' + data.error);
                return;
            }

            lastResult = data;
            $sqlPreview.textContent = data.sql;

            // Meta
            var meta = data.rowcount + ' row(s)';
            if (data.truncated) meta += ' (result truncated)';
            $resultsMeta.textContent = meta;

            // Header
            $resultsHead.innerHTML = '<tr>' + data.columns.map(function (c) {
                return '<th>' + c + '</th>';
            }).join('') + '</tr>';

            // Body
            var html = '';
            data.rows.forEach(function (row) {
                html += '<tr>' + row.map(function (cell) {
                    var v = (cell === null || cell === '') ? '<span class="text-muted">NULL</span>' : escapeHtml(String(cell));
                    return '<td class="small">' + v + '</td>';
                }).join('') + '</tr>';
            });
            if (data.rows.length === 0) {
                html = '<tr><td colspan="' + data.columns.length + '" class="text-center text-muted py-3">No rows returned.</td></tr>';
            }
            $resultsBody.innerHTML = html;
            $resultsCard.style.display = '';
            $btnExportCsv.style.display = '';
        })
        .catch(function (err) {
            $loading.style.display = 'none';
            $btnExecute.disabled = false;
            alert('Request failed: ' + err);
        });
    });

    // ── Export CSV ──
    $btnExportCsv.addEventListener('click', function () {
        if (!lastResult || !lastResult.rows.length) return;
        var csv = lastResult.columns.map(csvEscape).join(',') + '\n';
        lastResult.rows.forEach(function (row) {
            csv += row.map(function (cell) { return csvEscape(cell === null ? '' : String(cell)); }).join(',') + '\n';
        });
        var blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
        var url = URL.createObjectURL(blob);
        var a = document.createElement('a');
        a.href = url;
        a.download = $table.value + '_export.csv';
        a.click();
        URL.revokeObjectURL(url);
    });

    function csvEscape(val) {
        if (/[",\n\r]/.test(val)) return '"' + val.replace(/"/g, '""') + '"';
        return val;
    }

    function hideResults() {
        $resultsCard.style.display = 'none';
        $resultsHead.innerHTML = '';
        $resultsBody.innerHTML = '';
        $btnExportCsv.style.display = 'none';
        lastResult = null;
    }

    function escapeHtml(str) {
        var d = document.createElement('div');
        d.appendChild(document.createTextNode(str));
        return d.innerHTML;
    }

}());
</script>
</cfsavecontent>

<cfinclude template="/admin/layout.cfm">
