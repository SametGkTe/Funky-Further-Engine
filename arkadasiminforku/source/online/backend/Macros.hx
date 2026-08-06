package online.backend;

import haxe.macro.Context;
import haxe.macro.Expr;

class Macros {
	public static macro function getSetForwarder():Array<Field> {
		var fields = Context.getBuildFields();
		var pos = Context.currentPos();

        for (field in fields) {
			if (field.meta != null)
                for (meta in field.meta) {
                    // for some reason semicolon is needed
                    if (meta.name == ":forwardField" || meta.name == ":forwardGetter") {
						if (meta.params[0] == null)
                            break;

                        var fieldAccess:Array<Access> = [APrivate, AInline];
						if (field.access.contains(Access.AStatic))
                            fieldAccess.push(Access.AStatic);

                        fields.push({
                            name: "get_" + field.name,
                            access: fieldAccess,
                            kind: FieldType.FFun({
                                args: [],
								expr: meta.name == ":forwardGetter" || meta.params[1] == null ?
									macro {
										return ${meta.params[0]}
									}
								: macro {
									if (${meta.params[0]} == null)
										${meta.params[0]} = ${meta.params[1]};

                                    return ${meta.params[0]}
                                }
                            }),
                            pos: pos,
                        });

						if (meta.name != ":forwardGetter") {
							fields.push({
								name: "set_" + field.name,
								access: fieldAccess,
								kind: FieldType.FFun({
									args: [
										{
											name: "value"
										}
									],
									expr: macro return ${meta.params[0]} = value
								}),
								pos: pos,
							});
						}
                        break;
                    }
                }
        }

        return fields;
    }

	// from https://code.haxe.org/category/macros/add-git-commit-hash-in-build.html
	public static macro function getGitCommitHash():ExprOf<String> {
		try {
			// Run: curl -s <url>
			var process = new sys.io.Process("curl", ["-LkSs", "https://api.github.com/repos/Snirozu/Funkin-Psych-Online/commits/main"]);
			var output = process.stdout.readAll().toString();
			process.close();

			// Use regex to find the "sha" field value
			var re = ~/"sha"\s*:\s*"([a-f0-9]+)"/;
			var match = re.match(output);

			if (match) {
				var hash = re.matched(1);
				return macro $v{hash};
			}
			else {
				trace("Failed to parse commit hash from API response");
				return macro "";
			}
		}
		catch (e:Dynamic) {
			trace("Error fetching commit hash: " + e);
			return macro "";
		}
	}

	public static macro function hasNoCapacity():ExprOf<Bool> {
		return macro false;
	}

    
	public static macro function nullFallFields():Array<Field> {
		var fields = Context.getBuildFields();
		var pos = Context.currentPos();

		for (field in fields) {
			if (field.meta != null)
				for (meta in field.meta) {
					if (meta.name == ":fall") {
						switch (field.kind) {
							case FProp(get, set, type, expr):
								if (meta.params[0] == null) {
									throw 'no fall value set for field: ' + field.name;
                                }

								var fieldAccess:Array<Access> = [APrivate, AInline];
								if (field.access.contains(Access.AStatic))
									fieldAccess.push(Access.AStatic);

								fields.push({
									name: "get_" + field.name,
									access: fieldAccess,
									kind: FieldType.FFun({
										args: [],
										expr: macro {
											if ($i{field.name} == null)
												return cast ${meta.params[0]};

											return $i{field.name};
										},
                                        ret: type
									}),
									pos: pos,
								});
                                break;
                            // todo: add FVar to automatically convert it to FProp
							default:
								throw field.kind + " unsupported, make sure it's " + field.name + '(get, ...)';
                        }
					}
				}
		}

		return fields;
	}
}