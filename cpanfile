use GSG::Gitc::CPANfile $_environment;

# Project requirements go here...
requires 'List::Util', '>= 1.43';
test_requires 'Test::Strict';


1;
on develop => sub {
    requires 'Dist::Zilla::PluginBundle::Author::GSG::Internal';
};
