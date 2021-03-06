# Flutter's Build Infrastructure

This directory exists to support building Flutter on our build infrastructure.

The results of such builds are viewable at
https://build.chromium.org/p/client.flutter/waterfall

The external master pages do not allow forcing new builds. Contact
@eseidelGoogle or another member of Google's Flutter team if you need to do
that.

Our infrastructure is broken into two parts.  A buildbot master specified by our
[builders.pyl](https://chromium.googlesource.com/chromium/tools/build.git/+/master/masters/master.client.flutter/builders.pyl)
file, and a [set of
recipes](https://chromium.googlesource.com/chromium/tools/build.git/+/master/scripts/slave/recipes/flutter)
which we run on that master.  Both of these technologies are highly specific to
Google's Chromium project. We're just borrowing some of their infrastructure.

## Prerequisites

- [install depot_tools](http://www.chromium.org/developers/how-tos/install-depot-tools)
- Python package installer: `sudo apt-get install python-pip`
- Python coverage package (only needed for `training_simulation`): `sudo pip install coverage`

## Getting the code

The following will get way more than just recipe code, but it _will_ get the recipe code:

```bash
mkdir chrome_infra
cd chrome_infra
fetch infra
```

More detailed instructions can be found [here](https://chromium.googlesource.com/infra/infra/+/master/doc/source.md).

Most of the functionality for recipes comes from `recipe_modules`, which are
unfortunately spread to many separate repositories.  After checking out the code
search for files named `api.py` or `example.py` under `infra/build`.

## Editing a recipe

Flutter has one recipe per repository. Currently
[flutter/flutter](https://chromium.googlesource.com/chromium/tools/build.git/+/master/scripts/slave/recipes/flutter/flutter.py)
and
[flutter/engine](https://chromium.googlesource.com/chromium/tools/build.git/+/master/scripts/slave/recipes/flutter/engine.py).

Recipes are just Python.  They are
[documented](https://github.com/luci/recipes-py/blob/master/doc/user_guide.md)
by the [luci/recipes-py github project](https://github.com/luci/recipes-py).

The typical cycle for editing a recipe is:

1. Make your edits.
2. Run `build/scripts/slave/recipes.py simulation_test train flutter` to update expected files  (remove the flutter if you need to do a global update).
3. Run `build/scripts/tools/run_recipe.py flutter/flutter` (or flutter/engine) if something was strange during training and you need to run it locally.
4. Upload the patch (`git commit`, `git cl upload`) and send it to someone in the `recipes/flutter/OWNERS` file for review.

## Editing the client.flutter buildbot master

Flutter uses Chromium's fancy
[builders.pyl](https://chromium.googlesource.com/infra/infra/+/master/doc/users/services/buildbot/builders.pyl.md)
master generation system.  Chromium hosts 100s (if not 1000s) of buildbot
masters and thus has lots of infrastructure for turning them up and down.
Eventually all of buildbot is planned to be replaced by other infrastructure,
but for now flutter has its own client.flutter master.

You would need to edit client.flutter's master in order to add slaves (talk to
@eseidelGoogle), add builder groups, or to change the html layout of
https://build.chromium.org/p/client.flutter.  Carefully follow the [builders.pyl
docs](https://chromium.googlesource.com/infra/infra/+/master/doc/users/services/buildbot/builders.pyl.md)
to do so.

## Future Directions

We would like to host our own recipes instead of storing them in
[build](https://chromium.googlesource.com/chromium/tools/build.git/+/master/scripts/slave/recipes/flutter).
Support for [cross-repository
recipes](https://github.com/luci/recipes-py/blob/master/doc/cross_repo.md) is
in-progress.  If you view the git log of this directory, you'll see we initially
tried, but it's not quite ready.
