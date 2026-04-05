<cfset content = "
<h1 class='mb-4'>Directory Admin Dashboard</h1>

<div class='row g-4'>
    <div class='col-md-4'>
        <div class='card shadow-sm'>
            <div class='card-body'>
                <h5 class='card-title'>Users</h5>
                <p class='card-text'>Manage UHCO faculty, staff, residents, alumni, and students.</p>
                <a href='/dir/admin/users/index.cfm' class='btn btn-primary'>Manage Users</a>
            </div>
        </div>
    </div>

    <div class='col-md-4'>
        <div class='card shadow-sm'>
            <div class='card-body'>
                <h5 class='card-title'>Flags</h5>
                <p class='card-text'>Assign user roles such as Faculty, Staff, Resident, Alumni.</p>
                <a href='/dir/admin/flags/index.cfm' class='btn btn-primary'>Manage Flags</a>
            </div>
        </div>
    </div>

    <div class='col-md-4'>
        <div class='card shadow-sm'>
            <div class='card-body'>
                <h5 class='card-title'>Organizations</h5>
                <p class='card-text'>Manage departments, divisions, and faculty groups.</p>
                <a href='/dir/admin/orgs/index.cfm' class='btn btn-primary'>Manage Orgs</a>
            </div>
        </div>
    </div>
</div>
" />

<cfinclude template="/dir/admin/layout.cfm">