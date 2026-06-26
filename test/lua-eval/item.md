## Section
This is like a Hugo shortcode, except using etlua:

<%= "<escaped html>" %>

And <%- table.concat({ "<em>", "inline", "</em>" }) %>, too!

<ul>
<% for _, str in ipairs({ "foo", "bar" }) do -%>
<li><%= str %></li>
<% end -%>
</ul>

