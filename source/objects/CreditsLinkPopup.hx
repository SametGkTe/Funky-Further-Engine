package objects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.math.FlxMath;
import flixel.util.FlxColor;

typedef LinkEntry =
{
    var type:String;
    var url:String;
    var displayName:String;
};

class CreditsLinkPopup extends FlxSpriteGroup
{
    var bgPanel:FlxSprite;
    var headerText:FlxText;
    var linkTexts:Array<FlxText> = [];
    var curLinkSelected:Int = 0;
    var links:Array<LinkEntry> = [];
    var isActive:Bool = false;
    var selectIndicator:FlxSprite;
    var personName:String = "";

    var panelWidth:Int = 480;
    var linkHeight:Int = 48;
    var headerHeight:Int = 56;
    var padding:Int = 16;
    var cornerX:Float = 0;
    var cornerY:Float = 0;

    public var onClose:Void->Void = null;
    public var onLinkConfirm:String->Void = null;

    static var linkTypeNames:Map<String, String> = [
        "youtube" => "YouTube",
        "twitter" => "Twitter / X",
        "x" => "Twitter / X",
        "tiktok" => "TikTok",
        "discord" => "Discord",
        "github" => "GitHub",
        "kofi" => "Ko-fi",
        "instagram" => "Instagram",
        "website" => "Website",
        "twitch" => "Twitch",
        "newgrounds" => "Newgrounds",
        "bsky" => "Bluesky",
        "spotify" => "Spotify",
        "soundcloud" => "SoundCloud",
        "bandcamp" => "Bandcamp",
        "patreon" => "Patreon",
        "link" => "Link"
    ];

    static var linkTypeColors:Map<String, FlxColor> = [
        "youtube" => 0xFFFF0000,
        "twitter" => 0xFF1DA1F2,
        "x" => 0xFF1DA1F2,
        "tiktok" => 0xFFFF0050,
        "discord" => 0xFF5865F2,
        "github" => 0xFFFFFFFF,
        "kofi" => 0xFFFF5E5B,
        "instagram" => 0xFFE1306C,
        "website" => 0xFFAAAAAA,
        "twitch" => 0xFF9146FF,
        "newgrounds" => 0xFFFFA500,
        "bsky" => 0xFF0085FF,
        "spotify" => 0xFF1DB954,
        "soundcloud" => 0xFFFF5500,
        "bandcamp" => 0xFF629AA9,
        "patreon" => 0xFFF96854,
        "link" => 0xFFCCCCCC
    ];

    public function new()
    {
        super();
        scrollFactor.set();
        visible = false;
    }

    public function openPopup(name:String, rawLinkData:String, startX:Float, startY:Float):Void
    {
        personName = name;
        links = parseLinkData(rawLinkData);

        if (links.length == 0)
        {
            if (onClose != null) onClose();
            return;
        }

        clearPopup();

        var totalLinks = links.length;
        var panelHeight = headerHeight + (totalLinks * linkHeight) + padding * 2;

        cornerX = startX;
        cornerY = startY;

        if (cornerX + panelWidth > FlxG.width - 20)
            cornerX = FlxG.width - panelWidth - 20;
        if (cornerY + panelHeight > FlxG.height - 20)
            cornerY = FlxG.height - panelHeight - 20;
        if (cornerX < 20) cornerX = 20;
        if (cornerY < 20) cornerY = 20;

        bgPanel = new FlxSprite(cornerX, cornerY).makeGraphic(panelWidth, Std.int(panelHeight), 0xFF000000);
        bgPanel.alpha = 0;
        add(bgPanel);

        var topLine = new FlxSprite(cornerX, cornerY).makeGraphic(panelWidth, 3, 0xFFFFFFFF);
        topLine.alpha = 0;
        add(topLine);
        FlxTween.tween(topLine, {alpha: 0.3}, 0.2, {startDelay: 0.05});

        headerText = new FlxText(cornerX + padding, cornerY + padding, panelWidth - padding * 2, personName, 22);
        headerText.setFormat("VCR OSD Mono", 22, FlxColor.WHITE, LEFT);
        headerText.alpha = 0;
        add(headerText);

        var separatorY = cornerY + headerHeight;
        var separator = new FlxSprite(cornerX + padding, separatorY).makeGraphic(panelWidth - padding * 2, 1, 0xFFFFFFFF);
        separator.alpha = 0;
        add(separator);
        FlxTween.tween(separator, {alpha: 0.2}, 0.2, {startDelay: 0.1});

        selectIndicator = new FlxSprite(cornerX + 4, 0).makeGraphic(4, linkHeight - 8, 0xFFFFFFFF);
        selectIndicator.alpha = 0;
        add(selectIndicator);

        for (i in 0...totalLinks)
        {
            var link = links[i];
            var ly = separatorY + 8 + (i * linkHeight);

            var typeColor = linkTypeColors.get(link.type) ?? 0xFFCCCCCC;

            var dot = new FlxSprite(cornerX + padding + 2, ly + linkHeight / 2 - 3).makeGraphic(6, 6, typeColor);
            dot.alpha = 0;
            add(dot);
            FlxTween.tween(dot, {alpha: 0.9}, 0.15, {startDelay: 0.1 + i * 0.04});

            var linkText = new FlxText(cornerX + padding + 16, ly + 8, panelWidth - padding * 2 - 20, link.displayName, 18);
            linkText.setFormat("VCR OSD Mono", 18, FlxColor.WHITE, LEFT);
            linkText.alpha = 0;
            linkTexts.push(linkText);
            add(linkText);

            FlxTween.tween(linkText, {alpha: 0.6}, 0.15, {startDelay: 0.1 + i * 0.04});
        }

        FlxTween.tween(bgPanel, {alpha: 0.85}, 0.2);
        FlxTween.tween(headerText, {alpha: 1.0}, 0.2, {startDelay: 0.05});

        curLinkSelected = 0;
        updateLinkSelection();

        visible = true;
        isActive = true;
    }

    function parseLinkData(raw:String):Array<LinkEntry>
    {
        var result:Array<LinkEntry> = [];
        if (raw == null || raw.length < 4) return result;

        if (!raw.contains("::"))
        {
            result.push({
                type: "link",
                url: raw,
                displayName: "Link"
            });
            return result;
        }

        var parts = raw.split("||");
        for (part in parts)
        {
            var segments = part.split("::");
            if (segments.length >= 2)
            {
                var linkType = segments[0].toLowerCase().trim();
                var linkUrl = segments[1].trim();
                var displayName = linkTypeNames.get(linkType) ?? linkType;

                result.push({
                    type: linkType,
                    url: linkUrl,
                    displayName: displayName
                });
            }
        }
        return result;
    }

    function updateLinkSelection():Void
    {
        for (i in 0...linkTexts.length)
        {
            var txt = linkTexts[i];
            if (i == curLinkSelected)
            {
                txt.alpha = 1.0;
                txt.color = linkTypeColors.get(links[i].type) ?? 0xFFFFFFFF;

                var targetY = txt.y + (linkHeight - selectIndicator.height) / 2 - 8;
                selectIndicator.alpha = 0.9;
                selectIndicator.color = txt.color;
                FlxTween.cancelTweensOf(selectIndicator);
                FlxTween.tween(selectIndicator, {y: targetY}, 0.12, {ease: FlxEase.quartOut});
            }
            else
            {
                txt.alpha = 0.45;
                txt.color = FlxColor.WHITE;
            }
        }
    }

    public function handleInput(controls:Dynamic):Void
    {
        if (!isActive) return;

        if (controls.UI_UP_P)
        {
            curLinkSelected = (curLinkSelected - 1 + links.length) % links.length;
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
            updateLinkSelection();
        }
        if (controls.UI_DOWN_P)
        {
            curLinkSelected = (curLinkSelected + 1) % links.length;
            FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
            updateLinkSelection();
        }
        if (controls.ACCEPT)
        {
            var selectedLink = links[curLinkSelected];
            if (selectedLink != null && onLinkConfirm != null)
            {
                FlxG.sound.play(Paths.sound('confirmMenu'));
                onLinkConfirm(selectedLink.url);
            }
        }
        if (controls.BACK)
        {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            closePopup();
        }
    }

    public function closePopup():Void
    {
        isActive = false;

        FlxTween.tween(this, {alpha: 0}, 0.2, {
            ease: FlxEase.quadIn,
            onComplete: function(_)
            {
                visible = false;
                alpha = 1;
                clearPopup();
                if (onClose != null) onClose();
            }
        });
    }

    function clearPopup():Void
    {
        for (member in members.copy())
        {
            if (member != null)
            {
                remove(member, true);
                member.destroy();
            }
        }
        linkTexts = [];
        bgPanel = null;
        headerText = null;
        selectIndicator = null;
    }

    public function isOpen():Bool
    {
        return isActive;
    }

    override function destroy()
    {
        clearPopup();
        super.destroy();
    }
}