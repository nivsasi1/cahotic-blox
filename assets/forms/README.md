# Forms

Drop monster models here as `.rbxm` files. Each file becomes one form players can turn into.

A model needs:

- a `Humanoid`
- a part named `HumanoidRootPart`, set as the model's `PrimaryPart`
- a working rig, with Motor6D joints, so it can move

The file name is the form's name. `Dragon.rbxm` shows up in game as Dragon.

While this folder has no models, the game builds the placeholder forms listed in
`src/shared/Config.luau`.
