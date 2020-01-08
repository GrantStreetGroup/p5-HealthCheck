use GSG::Gitc::CPANfile $_environment;

requires 'List::Util', '>= 1.43';

on test => sub {
    requires 'Test::Strict';
};

on develop => sub {
    requires 'Dist::Zilla::PluginBundle::Author::GSG::Internal';
};

1;
