package options;

import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.gamepad.FlxGamepadManager;

import objects.CheckboxThingie;
import objects.AttachedText;
import options.Option;
import backend.InputFormatter;

class BaseOptionsMenu extends MusicBeatSubstate
{
	private var curOption:Option = null;
	private var curSelected:Int = 0;
	private var optionsArray:Array<Option>;

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var checkboxGroup:FlxTypedGroup<CheckboxThingie>;
	private var grpTexts:FlxTypedGroup<AttachedText>;

	private var descBox:FlxSprite;
	private var descText:FlxText;

	public var title:String;
	public var rpcTitle:String;

	public var bg:FlxSprite;

	var camTargetY:Float = 0;

	var dropdownOpen:Bool = false;
	var dropdownOptionIndex:Int = -1; // which option in optionsArray is open
	var dropdownSubItems:Array<Alphabet> = [];
	var dropdownSubSelected:Int = 0;
	var blockAfterClose:Int = 0;

	// Store the visual list: optionsArray indices + dropdown sub-item indices
	// displayList[i] = { type: 'option', index: N } or { type: 'sub', subIndex: N }
	var displayList:Array<DisplayEntry> = [];

	public function new()
	{
		controls.isInSubstate = true;

		super();

		if(title == null) title = 'Options';
		if(rpcTitle == null) rpcTitle = 'Options Menu';

		#if DISCORD_ALLOWED
		DiscordClient.changePresence(rpcTitle, null);
		#end

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFea71fd;
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set();
		add(bg);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		grpTexts = new FlxTypedGroup<AttachedText>();
		add(grpTexts);

		checkboxGroup = new FlxTypedGroup<CheckboxThingie>();
		add(checkboxGroup);

		descBox = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		descBox.alpha = 0.6;
		descBox.scrollFactor.set();
		add(descBox);

		var titleText:Alphabet = new Alphabet(75, 45, title, true);
		titleText.setScale(0.6);
		titleText.alpha = 0.4;
		titleText.scrollFactor.set();
		add(titleText);

		descText = new FlxText(50, 600, 1180, "", 32);
		descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		descText.borderSize = 2.4;
		add(descText);

		for (i in 0...optionsArray.length)
		{
			var optionText:Alphabet = new Alphabet(220, 260, optionsArray[i].name, false);
			optionText.isMenuItem = true;
			optionText.targetY = i;
			grpOptions.add(optionText);

			if(optionsArray[i].type == BOOL)
			{
				var checkbox:CheckboxThingie = new CheckboxThingie(optionText.x - 105, optionText.y, Std.string(optionsArray[i].getValue()) == 'true');
				checkbox.sprTracker = optionText;
				checkbox.ID = i;
				checkboxGroup.add(checkbox);
			}
			else if(optionsArray[i].type == DROPDOWN)
			{
				optionText.x -= 80;
				optionText.startPosition.x -= 80;
				// Show arrow indicator
				var displayVal:String = getDropdownArrowText(optionsArray[i], false);
				var valueText:AttachedText = new AttachedText(displayVal, optionText.width + 60);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				grpTexts.add(valueText);
				optionsArray[i].child = valueText;
			}
			else
			{
				optionText.x -= 80;
				optionText.startPosition.x -= 80;
				var valueText:AttachedText = new AttachedText('' + optionsArray[i].getValue(), optionText.width + 60);
				valueText.sprTracker = optionText;
				valueText.copyAlpha = true;
				valueText.ID = i;
				grpTexts.add(valueText);
				optionsArray[i].child = valueText;
			}
			updateTextFrom(optionsArray[i]);
		}

		rebuildDisplayList();
		changeSelection();
		reloadCheckboxes();

		addTouchPad('LEFT_FULL', 'A_B_C');
	}

	// ========== DISPLAY LIST ==========
	function rebuildDisplayList()
	{
		displayList = [];
		for (i in 0...optionsArray.length)
		{
			displayList.push({type: OPTION, optionIndex: i, subIndex: -1});

			// If this dropdown is open, add sub-items after it
			if (optionsArray[i].type == DROPDOWN && dropdownOpen && dropdownOptionIndex == i)
			{
				var opt = optionsArray[i];
				var labels = opt.dropdownLabels != null ? opt.dropdownLabels : opt.options;
				for (si in 0...opt.options.length)
				{
					displayList.push({type: SUB_ITEM, optionIndex: i, subIndex: si});
				}
			}
		}

		// Rebuild targetY for all grpOptions members
		var optIdx:Int = 0;
		var displayIdx:Int = 0;
		for (entry in displayList)
		{
			if (entry.type == OPTION)
			{
				if (optIdx < grpOptions.members.length)
				{
					grpOptions.members[optIdx].targetY = displayIdx - curSelected;
				}
				optIdx++;
			}
			displayIdx++;
		}

		// Rebuild sub-item Alphabet visuals
		rebuildDropdownSubItems();
	}

	function rebuildDropdownSubItems()
	{
		// Remove old sub-items
		for (sub in dropdownSubItems)
		{
			sub.visible = false;
			sub.active = false;
			remove(sub);
		}
		dropdownSubItems = [];

		if (!dropdownOpen || dropdownOptionIndex < 0) return;

		var opt = optionsArray[dropdownOptionIndex];
		var labels = opt.dropdownLabels != null ? opt.dropdownLabels : opt.options;
		var currentValue:String = opt.getValue();

		for (si in 0...opt.options.length)
		{
			var label:String = si < labels.length ? labels[si] : opt.options[si];
			var isActive:Bool = (opt.options[si] == currentValue);
			var prefix:String = isActive ? "> " : "- ";

			var subText:Alphabet = new Alphabet(280, 260, prefix + label, false);
			subText.isMenuItem = true;
			subText.setScale(0.7);
			subText.alpha = 0.6;
			add(subText);
			dropdownSubItems.push(subText);
		}

		updateDisplayPositions();
	}

	function updateDisplayPositions()
	{
		var visualIndex:Int = 0;
		var optIdx:Int = 0;
		var subIdx:Int = 0;

		// Find where curSelected maps to in display list
		var curDisplayIndex:Int = 0;
		if (dropdownOpen)
		{
			// curSelected is display index
			curDisplayIndex = curSelected;
		}
		else
		{
			curDisplayIndex = curSelected;
		}

		for (di in 0...displayList.length)
		{
			var entry = displayList[di];
			if (entry.type == OPTION)
			{
				if (entry.optionIndex < grpOptions.members.length)
				{
					grpOptions.members[entry.optionIndex].targetY = di - curDisplayIndex;
				}
			}
			else if (entry.type == SUB_ITEM)
			{
				if (subIdx < dropdownSubItems.length)
				{
					dropdownSubItems[subIdx].targetY = di - curDisplayIndex;
				}
				subIdx++;
			}
		}
	}

	// ========== DROPDOWN ARROW TEXT ==========
	function getDropdownArrowText(option:Option, isOpen:Bool):String
	{
		return isOpen ? 'V' : '>';
	}

	function getDropdownDisplayValue(option:Option):String
	{
		if (option.dropdownLabels != null && option.curOption >= 0 && option.curOption < option.dropdownLabels.length)
			return '< ' + option.dropdownLabels[option.curOption] + ' >';
		return '< ' + option.getValue() + ' >';
	}

	// ========== DROPDOWN OPEN/CLOSE ==========
	function openDropdownInline(optionIndex:Int)
	{
		var opt = optionsArray[optionIndex];
		if (opt.type != DROPDOWN || opt.options == null) return;

		dropdownOpen = true;
		dropdownOptionIndex = optionIndex;
		dropdownSubSelected = opt.curOption;

		// Update arrow to V
		if (opt.child != null)
			opt.child.text = getDropdownArrowText(opt, true);

		rebuildDisplayList();

		// Move curSelected to first sub-item
		for (di in 0...displayList.length)
		{
			if (displayList[di].type == SUB_ITEM && displayList[di].optionIndex == optionIndex)
			{
				curSelected = di + dropdownSubSelected;
				break;
			}
		}

		updateSelectionVisuals();
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function closeDropdownInline()
	{
		if (!dropdownOpen) return;

		// Update arrow back to >
		var opt = optionsArray[dropdownOptionIndex];
		if (opt.child != null)
			opt.child.text = getDropdownArrowText(opt, false);

		dropdownOpen = false;

		// Find the option index in display list to set curSelected
		var targetDisplay:Int = dropdownOptionIndex;
		curSelected = dropdownOptionIndex; // This will be correct after rebuild

		dropdownOptionIndex = -1;
		dropdownSubSelected = 0;
		blockAfterClose = 3;

		rebuildDisplayList();

		// curSelected should point to the option that was open
		curSelected = targetDisplay;
		updateSelectionVisuals();

		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function selectDropdownSubItem()
	{
		if (!dropdownOpen || dropdownOptionIndex < 0) return;

		var opt = optionsArray[dropdownOptionIndex];

		// Find which sub-item is selected
		var subIndex:Int = -1;
		var entry = displayList[curSelected];
		if (entry.type == SUB_ITEM)
			subIndex = entry.subIndex;

		if (subIndex < 0 || subIndex >= opt.options.length) return;

		opt.curOption = subIndex;
		opt.setValue(opt.options[subIndex]);
		opt.change();

		closeDropdownInline();
		updateTextFrom(opt);
		FlxG.sound.play(Paths.sound('confirmMenu'));
	}

	// ========== SELECTION VISUALS ==========
	function updateSelectionVisuals()
	{
		updateDisplayPositions();

		// Update option alphas
		for (oi in 0...grpOptions.members.length)
		{
			grpOptions.members[oi].alpha = 0.6;
		}

		// Update text alphas
		for (text in grpTexts)
		{
			text.alpha = 0.6;
		}

		// Update sub-item alphas
		for (sub in dropdownSubItems)
		{
			sub.alpha = 0.6;
		}

		// Highlight current selection
		if (curSelected >= 0 && curSelected < displayList.length)
		{
			var entry = displayList[curSelected];
			if (entry.type == OPTION)
			{
				if (entry.optionIndex < grpOptions.members.length)
					grpOptions.members[entry.optionIndex].alpha = 1;

				for (text in grpTexts)
					if (text.ID == entry.optionIndex) text.alpha = 1;

				// Update curOption and desc
				curOption = optionsArray[entry.optionIndex];
				descText.text = curOption.description;
			}
			else if (entry.type == SUB_ITEM)
			{
				var subLocalIndex:Int = entry.subIndex;
				if (subLocalIndex >= 0 && subLocalIndex < dropdownSubItems.length)
					dropdownSubItems[subLocalIndex].alpha = 1;

				// Keep parent option highlighted too
				if (entry.optionIndex < grpOptions.members.length)
					grpOptions.members[entry.optionIndex].alpha = 0.8;

				// Show parent description
				curOption = optionsArray[entry.optionIndex];
				descText.text = curOption.description;
			}
		}

		// Update desc box
		descText.screenCenter(Y);
		descText.y += 270;
		descBox.setPosition(descText.x - 10, descText.y - 10);
		descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
		descBox.updateHitbox();

		// Update camera target
		if (curSelected >= 0 && curSelected < displayList.length)
		{
			var entry = displayList[curSelected];
			if (entry.type == OPTION && entry.optionIndex < grpOptions.members.length)
			{
				camTargetY = grpOptions.members[entry.optionIndex].startPosition.y - (FlxG.height / 2);
			}
			else if (entry.type == SUB_ITEM)
			{
				var subLocalIndex:Int = entry.subIndex;
				if (subLocalIndex >= 0 && subLocalIndex < dropdownSubItems.length)
				{
					// Approximate position
					var parentItem = grpOptions.members[entry.optionIndex];
					camTargetY = parentItem.startPosition.y + (subLocalIndex + 1) * 60 - (FlxG.height / 2);
				}
			}
		}
	}

	// ========== STANDARD ==========
	function getMenuCamera():FlxCamera
	{
		if (cameras != null && cameras.length > 0 && cameras[0] != null)
			return cameras[0];
		return FlxG.camera;
	}

	public function addOption(option:Option) {
		if(optionsArray == null || optionsArray.length < 1) optionsArray = [];
		optionsArray.push(option);
		return option;
	}

	var nextAccept:Int = 5;
	var holdTime:Float = 0;
	var holdValue:Float = 0;

	var bindingKey:Bool = false;
	var holdingEsc:Float = 0;
	var bindingBlack:FlxSprite;
	var bindingText:Alphabet;
	var bindingText2:Alphabet;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if(bindingKey)
		{
			bindingKeyUpdate(elapsed);
			return;
		}

		if (blockAfterClose > 0)
		{
			blockAfterClose--;
			getMenuCamera().scroll.y = FlxMath.lerp(getMenuCamera().scroll.y, camTargetY, 0.14);
			return;
		}

		// ========== DROPDOWN OPEN ==========
		if (dropdownOpen)
		{
			if (controls.UI_UP_P)
			{
				curSelected--;
				// Skip over OPTION entries, stay in SUB_ITEM range
				while (curSelected >= 0 && displayList[curSelected].type != SUB_ITEM)
					curSelected--;
				if (curSelected < 0)
				{
					// Wrap to last sub-item
					curSelected = displayList.length - 1;
					while (curSelected >= 0 && displayList[curSelected].type != SUB_ITEM)
						curSelected--;
				}
				updateSelectionVisuals();
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}

			if (controls.UI_DOWN_P)
			{
				curSelected++;
				while (curSelected < displayList.length && displayList[curSelected].type != SUB_ITEM)
					curSelected++;
				if (curSelected >= displayList.length)
				{
					// Wrap to first sub-item
					curSelected = 0;
					while (curSelected < displayList.length && displayList[curSelected].type != SUB_ITEM)
						curSelected++;
				}
				updateSelectionVisuals();
				FlxG.sound.play(Paths.sound('scrollMenu'));
			}

			if (controls.ACCEPT)
			{
				selectDropdownSubItem();
			}

			if (controls.BACK)
			{
				closeDropdownInline();
			}

			getMenuCamera().scroll.y = FlxMath.lerp(getMenuCamera().scroll.y, camTargetY, 0.14);
			return;
		}

		// ========== NORMAL MODE ==========
		if (controls.UI_UP_P) changeSelection(-1);
		if (controls.UI_DOWN_P) changeSelection(1);

		if (controls.BACK)
		{
			close();
			FlxG.sound.play(Paths.sound('cancelMenu'));
		}

		if(nextAccept <= 0)
		{
			switch(curOption.type)
			{
				case BOOL:
					if(controls.ACCEPT)
					{
						FlxG.sound.play(Paths.sound('scrollMenu'));
						curOption.setValue((curOption.getValue() == true) ? false : true);
						curOption.change();
						reloadCheckboxes();
					}

				case DROPDOWN:
					if(controls.ACCEPT)
					{
						openDropdownInline(curSelected);
					}
					else if(controls.UI_LEFT_P)
					{
						curOption.curOption--;
						if (curOption.curOption < 0) curOption.curOption = curOption.options.length - 1;
						curOption.setValue(curOption.options[curOption.curOption]);
						updateTextFrom(curOption);
						curOption.change();
						FlxG.sound.play(Paths.sound('scrollMenu'));
					}
					else if(controls.UI_RIGHT_P)
					{
						curOption.curOption++;
						if (curOption.curOption >= curOption.options.length) curOption.curOption = 0;
						curOption.setValue(curOption.options[curOption.curOption]);
						updateTextFrom(curOption);
						curOption.change();
						FlxG.sound.play(Paths.sound('scrollMenu'));
					}

				case KEYBIND:
					if(controls.ACCEPT)
					{
						bindingBlack = new FlxSprite().makeGraphic(1, 1, FlxColor.WHITE);
						bindingBlack.scale.set(FlxG.width, FlxG.height);
						bindingBlack.updateHitbox();
						bindingBlack.alpha = 0;
						bindingBlack.scrollFactor.set();
						FlxTween.tween(bindingBlack, {alpha: 0.6}, 0.35, {ease: FlxEase.linear});
						add(bindingBlack);

						bindingText = new Alphabet(FlxG.width / 2, 160, Language.getPhrase('controls_rebinding', 'Rebinding {1}', [curOption.name]), false);
						bindingText.alignment = CENTERED;
						bindingText.scrollFactor.set();
						add(bindingText);

						final escape:String = (controls.mobileC) ? "B" : "ESC";
						final backspace:String = (controls.mobileC) ? "C" : "Backspace";

						bindingText2 = new Alphabet(FlxG.width / 2, 340, Language.getPhrase('controls_rebinding2', 'Hold {1} to Cancel\nHold {2} to Delete', [escape, backspace]), true);
						bindingText2.alignment = CENTERED;
						bindingText2.scrollFactor.set();
						add(bindingText2);

						bindingKey = true;
						holdingEsc = 0;
						ClientPrefs.toggleVolumeKeys(false);
						FlxG.sound.play(Paths.sound('scrollMenu'));
					}

				default:
					if(controls.UI_LEFT || controls.UI_RIGHT)
					{
						var pressed = (controls.UI_LEFT_P || controls.UI_RIGHT_P);
						if(holdTime > 0.5 || pressed)
						{
							if(pressed)
							{
								var add:Dynamic = null;
								if(curOption.type != STRING)
									add = controls.UI_LEFT ? -curOption.changeValue : curOption.changeValue;

								switch(curOption.type)
								{
									case INT, FLOAT, PERCENT:
										holdValue = curOption.getValue() + add;
										if(holdValue < curOption.minValue) holdValue = curOption.minValue;
										else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

										if(curOption.type == INT)
										{
											holdValue = Math.round(holdValue);
											curOption.setValue(holdValue);
										}
										else
										{
											holdValue = FlxMath.roundDecimal(holdValue, curOption.decimals);
											curOption.setValue(holdValue);
										}

									case STRING:
										var num:Int = curOption.curOption;
										if(controls.UI_LEFT_P) --num;
										else num++;

										if(num < 0)
											num = curOption.options.length - 1;
										else if(num >= curOption.options.length)
											num = 0;

										curOption.curOption = num;
										curOption.setValue(curOption.options[num]);

									default:
								}
								updateTextFrom(curOption);
								curOption.change();
								FlxG.sound.play(Paths.sound('scrollMenu'));
							}
							else if(curOption.type != STRING)
							{
								holdValue += curOption.scrollSpeed * elapsed * (controls.UI_LEFT ? -1 : 1);
								if(holdValue < curOption.minValue) holdValue = curOption.minValue;
								else if (holdValue > curOption.maxValue) holdValue = curOption.maxValue;

								switch(curOption.type)
								{
									case INT:
										curOption.setValue(Math.round(holdValue));
									case PERCENT:
										curOption.setValue(FlxMath.roundDecimal(holdValue, curOption.decimals));
									default:
								}
								updateTextFrom(curOption);
								curOption.change();
							}
						}

						if(curOption.type != STRING)
							holdTime += elapsed;
					}
					else if(controls.UI_LEFT_R || controls.UI_RIGHT_R)
					{
						if(holdTime > 0.5) FlxG.sound.play(Paths.sound('scrollMenu'));
						holdTime = 0;
					}
			}

			if(controls.RESET || touchPad.buttonC.justPressed)
			{
				var leOption:Option = optionsArray[curSelected];
				if(leOption.type != KEYBIND)
				{
					leOption.setValue(leOption.defaultValue);
					if(leOption.type != BOOL)
					{
						if(leOption.type == STRING || leOption.type == DROPDOWN)
							leOption.curOption = leOption.options.indexOf(leOption.getValue());
						updateTextFrom(leOption);
					}
				}
				else
				{
					leOption.setValue(!Controls.instance.controllerMode ? leOption.defaultKeys.keyboard : leOption.defaultKeys.gamepad);
					updateBind(leOption);
				}
				leOption.change();
				FlxG.sound.play(Paths.sound('cancelMenu'));
				reloadCheckboxes();
			}
		}

		if(nextAccept > 0) nextAccept -= 1;

		getMenuCamera().scroll.y = FlxMath.lerp(getMenuCamera().scroll.y, camTargetY, 0.14);
	}

	function bindingKeyUpdate(elapsed:Float)
	{
		if(touchPad.buttonB.pressed || FlxG.keys.pressed.ESCAPE || FlxG.gamepads.anyPressed(B))
		{
			holdingEsc += elapsed;
			if(holdingEsc > 0.5)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				closeBinding();
			}
		}
		else if (touchPad.buttonC.pressed || FlxG.keys.pressed.BACKSPACE || FlxG.gamepads.anyPressed(BACK))
		{
			holdingEsc += elapsed;
			if(holdingEsc > 0.5)
			{
				if (!controls.controllerMode) curOption.keys.keyboard = NONE;
				else curOption.keys.gamepad = NONE;
				updateBind(!controls.controllerMode ? InputFormatter.getKeyName(NONE) : InputFormatter.getGamepadName(NONE));
				FlxG.sound.play(Paths.sound('cancelMenu'));
				closeBinding();
			}
		}
		else
		{
			holdingEsc = 0;
			var changed:Bool = false;
			if(!controls.controllerMode)
			{
				if(FlxG.keys.justPressed.ANY || FlxG.keys.justReleased.ANY)
				{
					var keyPressed:FlxKey = cast (FlxG.keys.firstJustPressed(), FlxKey);
					var keyReleased:FlxKey = cast (FlxG.keys.firstJustReleased(), FlxKey);

					if(keyPressed != NONE && keyPressed != ESCAPE && keyPressed != BACKSPACE)
					{
						changed = true;
						curOption.keys.keyboard = keyPressed;
					}
					else if(keyReleased != NONE && (keyReleased == ESCAPE || keyReleased == BACKSPACE))
					{
						changed = true;
						curOption.keys.keyboard = keyReleased;
					}
				}
			}
			else if(FlxG.gamepads.anyJustPressed(ANY) || FlxG.gamepads.anyJustPressed(LEFT_TRIGGER) || FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER) || FlxG.gamepads.anyJustReleased(ANY))
			{
				var keyPressed:FlxGamepadInputID = NONE;
				var keyReleased:FlxGamepadInputID = NONE;
				if(FlxG.gamepads.anyJustPressed(LEFT_TRIGGER))
					keyPressed = LEFT_TRIGGER;
				else if(FlxG.gamepads.anyJustPressed(RIGHT_TRIGGER))
					keyPressed = RIGHT_TRIGGER;
				else
				{
					for (i in 0...FlxG.gamepads.numActiveGamepads)
					{
						var gamepad:FlxGamepad = FlxG.gamepads.getByID(i);
						if(gamepad != null)
						{
							keyPressed = gamepad.firstJustPressedID();
							keyReleased = gamepad.firstJustReleasedID();
							if(keyPressed != NONE || keyReleased != NONE) break;
						}
					}
				}

				if(keyPressed != NONE && keyPressed != FlxGamepadInputID.BACK && keyPressed != FlxGamepadInputID.B)
				{
					changed = true;
					curOption.keys.gamepad = keyPressed;
				}
				else if(keyReleased != NONE && (keyReleased == FlxGamepadInputID.BACK || keyReleased == FlxGamepadInputID.B))
				{
					changed = true;
					curOption.keys.gamepad = keyReleased;
				}
			}

			if(changed)
			{
				var key:String = null;
				if(!controls.controllerMode)
				{
					if(curOption.keys.keyboard == null) curOption.keys.keyboard = 'NONE';
					curOption.setValue(curOption.keys.keyboard);
					key = InputFormatter.getKeyName(FlxKey.fromString(curOption.keys.keyboard));
				}
				else
				{
					if(curOption.keys.gamepad == null) curOption.keys.gamepad = 'NONE';
					curOption.setValue(curOption.keys.gamepad);
					key = InputFormatter.getGamepadName(FlxGamepadInputID.fromString(curOption.keys.gamepad));
				}
				updateBind(key);
				FlxG.sound.play(Paths.sound('confirmMenu'));
				closeBinding();
			}
		}
	}

	final MAX_KEYBIND_WIDTH = 320;
	function updateBind(?text:String = null, ?option:Option = null)
	{
		if(option == null) option = curOption;
		if(text == null)
		{
			text = option.getValue();
			if(text == null) text = 'NONE';
			if(!controls.controllerMode)
				text = InputFormatter.getKeyName(FlxKey.fromString(text));
			else
				text = InputFormatter.getGamepadName(FlxGamepadInputID.fromString(text));
		}

		var bind:AttachedText = cast option.child;
		var attach:AttachedText = new AttachedText(text, bind.offsetX);
		attach.sprTracker = bind.sprTracker;
		attach.copyAlpha = true;
		attach.ID = bind.ID;
		playstationCheck(attach);
		attach.scaleX = Math.min(1, MAX_KEYBIND_WIDTH / attach.width);
		attach.x = bind.x;
		attach.y = bind.y;

		option.child = attach;
		grpTexts.insert(grpTexts.members.indexOf(bind), attach);
		grpTexts.remove(bind);
		bind.destroy();
	}

	function playstationCheck(alpha:Alphabet)
	{
		if(!controls.controllerMode) return;
		var gamepad:FlxGamepad = FlxG.gamepads.firstActive;
		var model:FlxGamepadModel = gamepad != null ? gamepad.detectedModel : UNKNOWN;
		var letter = alpha.letters[0];
		if(model == PS4)
		{
			switch(alpha.text)
			{
				case '[', ']':
					letter.image = 'alphabet_playstation';
					letter.updateHitbox();
					letter.offset.x += 4;
					letter.offset.y -= 5;
			}
		}
	}

	function closeBinding()
	{
		bindingKey = false;
		bindingBlack.destroy();
		remove(bindingBlack);
		bindingText.destroy();
		remove(bindingText);
		bindingText2.destroy();
		remove(bindingText2);
		ClientPrefs.toggleVolumeKeys(true);
	}

	function updateTextFrom(option:Option) {
		if(option.type == KEYBIND)
		{
			updateBind(option);
			return;
		}

		if(option.type == DROPDOWN)
		{
			if(option.child != null)
				option.child.text = getDropdownArrowText(option, dropdownOpen && optionsArray.indexOf(option) == dropdownOptionIndex);
			return;
		}

		var text:String = option.displayFormat;
		var val:Dynamic = option.getValue();
		if(option.type == PERCENT) val *= 100;
		var def:Dynamic = option.defaultValue;
		option.text = text.replace('%v', val).replace('%d', def);
	}

	override function handleTouchTap(x:Float, y:Float):Bool
	{
		#if mobile
		if (bindingKey || blockAfterClose > 0)
			return true;

		var cam = getMenuCamera();

		if (dropdownOpen)
		{
			var bestSub:Int = -1;
			var bestDist:Float = 60;
			for (si => sub in dropdownSubItems)
			{
				if (sub == null || !sub.visible) continue;
				var p = sub.getScreenPosition(cam);
				var d:Float = Math.abs(y - (p.y + sub.height / 2));
				if (d < bestDist && x > p.x - 120)
				{
					bestDist = d;
					bestSub = si;
				}
				p.put();
			}
			if (bestSub >= 0)
			{
				var di:Int = -1;
				for (k in 0...displayList.length)
				{
					var entry = displayList[k];
					if (entry.type == SUB_ITEM && entry.optionIndex == dropdownOptionIndex && entry.subIndex == bestSub)
					{
						di = k;
						break;
					}
				}
				if (di >= 0 && di != curSelected)
				{
					curSelected = di;
					updateSelectionVisuals();
					FlxG.sound.play(Paths.sound('scrollMenu'));
					return true;
				}
				if (di == curSelected)
				{
					selectDropdownSubItem();
					return true;
				}
			}
			return true;
		}

		var best:Int = -1;
		var bestDist:Float = 60;
		for (num => item in grpOptions.members)
		{
			if (item == null || !item.visible) continue;
			var p = item.getScreenPosition(cam);
			var d:Float = Math.abs(y - (p.y + item.height / 2));
			if (d < bestDist && x > p.x - 120 && x < p.x + 1100)
			{
				bestDist = d;
				best = num;
			}
			p.put();
		}
		if (best >= 0)
		{
			if (best != curSelected)
			{
				curSelected = best;
				changeSelection(0);
				return true;
			}
			return false;
		}
		#end
		return false;
	}

	function changeSelection(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, optionsArray.length - 1);

		descText.text = optionsArray[curSelected].description;
		descText.screenCenter(Y);
		descText.y += 270;

		descBox.setPosition(descText.x - 10, descText.y - 10);
		descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
		descBox.updateHitbox();

		for (num => item in grpOptions.members)
		{
			item.targetY = num - curSelected;
			item.alpha = 0.6;

			if (item.targetY == 0)
			{
				item.alpha = 1;
				camTargetY = item.startPosition.y - (FlxG.height / 2);
			}
		}

		for (text in grpTexts)
		{
			text.alpha = 0.6;
			if(text.ID == curSelected) text.alpha = 1;
		}

		curOption = optionsArray[curSelected];
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function reloadCheckboxes()
		for (checkbox in checkboxGroup)
			checkbox.daValue = Std.string(optionsArray[checkbox.ID].getValue()) == 'true';
}

enum DisplayEntryType {
	OPTION;
	SUB_ITEM;
}

typedef DisplayEntry = {
	var type:DisplayEntryType;
	var optionIndex:Int;
	var subIndex:Int;
}