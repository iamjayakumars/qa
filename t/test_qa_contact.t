use strict;
use warnings;
use lib qw(lib);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();

# First make sure the 'My QA query' saved search is gone.

log_in($sel, $config, 'admin');
if ($sel->is_text_present("My QA query")) {
    $sel->click_ok("link=My QA query");
    $sel->wait_for_page_to_load_ok(WAIT_TIME);
    $sel->title_is("Bug List: My QA query");
    $sel->click_ok("link=Forget Search 'My QA query'");
    $sel->wait_for_page_to_load_ok(WAIT_TIME);
    $sel->title_is("Search is gone");
    $sel->is_text_present_ok("OK, the My QA query search is gone.");
}

# Enable the QA contact field and file a new bug restricted to the 'Master' group
# with a powerless user as the QA contact. He should only be able to access the
# bug if the QA contact field is enabled, else he looses this privilege.

set_parameters($sel, { "Bug Fields" => {"useqacontact-on" => undef} });
file_bug_in_product($sel, 'TestProduct');
$sel->type_ok("qa_contact", $config->{unprivileged_user_login}, "Set the powerless user as QA contact");
my $bug_summary = "Test for QA contact";
$sel->type_ok("short_desc", $bug_summary);
$sel->type_ok("comment", "This is a test to check QA contact privs.");
$sel->check_ok('//input[@name="groups" and @value="Master"]');
my $bug1_id = create_bug($sel, $bug_summary);

# Create a saved search querying for all bugs with the powerless user
# as QA contact.

open_advanced_search_page($sel);
$sel->remove_all_selections_ok("product");
$sel->add_selection_ok("product", "TestProduct");
$sel->remove_all_selections("bug_status");
$sel->select_ok("f1", "label=QA Contact");
$sel->select_ok("o1", "label=is equal to");
$sel->type_ok("v1", $config->{unprivileged_user_login}, "Look for the powerless user as QA contact");
$sel->click_ok("Search");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug List");
$sel->is_element_present_ok("b$bug1_id", undef, "Bug $bug1_id is on the list");
$sel->is_text_present_ok("Test for QA contact");
$sel->type_ok("save_newqueryname", "My QA query");
$sel->click_ok("remember");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Search created");
my $text = trim($sel->get_text("message"));
ok($text =~ /OK, you have a new search named My QA query/, "New saved search 'My QA query'");
$sel->click_ok("link=My QA query");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug List: My QA query");
$sel->is_element_present_ok("b$bug1_id", undef, "Bug $bug1_id is on the list");
$sel->is_text_present_ok("Test for QA contact");

# The saved search should still work, even with the QA contact field disabled.
# ("work" doesn't mean you should still see all bugs, depending on your role
# and privs!)

set_parameters($sel, { "Bug Fields" => {"useqacontact-off" => undef} });
$sel->click_ok("link=My QA query");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug List: My QA query");
$sel->is_text_present_ok("One bug found");
$sel->is_element_present_ok("b$bug1_id", undef, "Bug $bug1_id is on the list");
$sel->click_ok("link=$bug1_id");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/^Bug $bug1_id /);
# The 'QA Contact' label must not be displayed.
ok(!$sel->is_text_present("QA Contact"), "The QA Contact label is not present");
logout($sel);

# You cannot access the bug when being logged out, as it's restricted
# to the Master group.

$sel->type_ok("quicksearch_top", $bug1_id);
$sel->click_ok("find_top");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Access Denied");
$sel->is_text_present_ok("You are not authorized to access bug");

# You are still not allowed to access the bug when logged in as the
# powerless user, as the QA contact field is disabled.
# Don't use it log_in() as we want to follow this specific link.

$sel->click_ok("link=log in to an account", undef, "Log in");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Log in to Bugzilla");
$sel->is_text_present_ok("Bugzilla needs a legitimate login and password to continue.");
$sel->type_ok("Bugzilla_login", $config->{unprivileged_user_login}, "Enter login name");
$sel->type_ok("Bugzilla_password", $config->{unprivileged_user_passwd}, "Enter password");
$sel->click_ok("log_in", undef, "Submit credentials");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Access Denied");
$sel->is_text_present_ok("You are not authorized to access bug");
logout($sel);

# Re-enable the QA contact field.

log_in($sel, $config, 'admin');
set_parameters($sel, { "Bug Fields" => {"useqacontact-on" => undef} });
logout($sel);

# Log in as the powerless user. As the QA contact field is enabled again,
# you can now access the restricted bug.

log_in($sel, $config, 'unprivileged');
$sel->click_ok("link=Preferences");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("User Preferences");
$sel->select_ok("state_addselfcc", "value=never");
$sel->click_ok("update");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("User Preferences");

open_advanced_search_page($sel);
$sel->remove_all_selections_ok("product");
$sel->add_selection_ok("product", "TestProduct");
$sel->remove_all_selections_ok("bug_status");
$sel->select_ok("f1", "label=QA Contact");
$sel->select_ok("o1", "label=is equal to");
$sel->type_ok("v1", $config->{unprivileged_user_login}, "Look for the powerless user as QA contact");
$sel->click_ok("Search");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Bug List");
$sel->is_text_present_ok("One bug found");
$sel->is_element_present_ok("b$bug1_id", undef, "Bug $bug1_id is on the list");
$sel->is_text_present_ok("Test for QA contact");
$sel->click_ok("link=$bug1_id");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_like(qr/Bug $bug1_id /);
$sel->click_ok("bz_qa_contact_edit_action");
$sel->value_is("qa_contact", $config->{unprivileged_user_login}, "The powerless user is the current QA contact");
$sel->check_ok("set_default_qa_contact");
edit_bug($sel, $bug1_id, $bug_summary);

# The user is no longer the QA contact, and he has no other role
# with the bug. He can no longer see it.

$sel->is_text_present_ok("(list of e-mails not available)");
$sel->click_ok("link=bug $bug1_id");
$sel->wait_for_page_to_load_ok(WAIT_TIME);
$sel->title_is("Access Denied");
logout($sel);
