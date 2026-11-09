# Forms

Drop monster models here as `.rbxm` files. Each file becomes one form players can turn into.

A model needs:

- a `Humanoid`
- a part named `HumanoidRootPart`, set as the model's `PrimaryPart`
- a working rig, with Motor6D joints or bones, so it can move
- a part named `Head`. It holds the name tag and counts as the headshot spot for the blaster.

Optional: a part named `RightHand` holds the toy blaster. Without one, the blaster sits on the right
side of the body.

Shots hit the model's parts, not its mesh. A bone rig's skinned mesh bends, but its parts don't,
so place the parts where the body really is.

The file name is the form's name. `Dragon.rbxm` shows up in game as Dragon.

While this folder has no models, the game builds the placeholder forms listed in
`src/shared/Config.luau`.
