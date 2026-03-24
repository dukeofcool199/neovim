{gitRev, ...}: let
  # Parse ESV Bible JSON at Nix evaluation time
  bibleData = builtins.fromJSON (builtins.readFile ./esv.json);

  # Helpers
  mod = a: b: a - (builtins.div a b) * b;
  hexCharToInt = c:
    {
      "0" = 0;
      "1" = 1;
      "2" = 2;
      "3" = 3;
      "4" = 4;
      "5" = 5;
      "6" = 6;
      "7" = 7;
      "8" = 8;
      "9" = 9;
      "a" = 10;
      "b" = 11;
      "c" = 12;
      "d" = 13;
      "e" = 14;
      "f" = 15;
    }
    .${
      c
    };
  hexToInt = hex:
    builtins.foldl'
    (acc: c: acc * 16 + hexCharToInt c)
    0
    (builtins.genList (i: builtins.substring i 1 hex) (builtins.stringLength hex));
  sortNumeric = list:
    builtins.sort (a: b: (builtins.fromJSON a) < (builtins.fromJSON b)) list;

  # Two 32-bit numbers from different portions of the SHA
  n1 = hexToInt (builtins.substring 0 8 gitRev);
  n2 = hexToInt (builtins.substring 8 8 gitRev);

  # Select book (alphabetical sort for determinism)
  bookNames = builtins.sort builtins.lessThan (builtins.attrNames bibleData);
  bookIdx = mod n1 (builtins.length bookNames);
  bookName = builtins.elemAt bookNames bookIdx;
  book = bibleData.${bookName};

  # Select chapter (numeric sort)
  chapters = sortNumeric (builtins.attrNames book);
  chIdx = mod n2 (builtins.length chapters);
  chapterKey = builtins.elemAt chapters chIdx;
  chapter = book.${chapterKey};

  # Select verse (numeric sort, combined hash for different distribution)
  verses = sortNumeric (builtins.attrNames chapter);
  vIdx = mod (n1 + n2) (builtins.length verses);
  verseKey = builtins.elemAt verses vIdx;
  verseText = chapter.${verseKey};

  fullRef = "${bookName} ${chapterKey}:${verseKey}";

  # Serialize entire chapter as a Lua table for the popup
  chapterLua = builtins.concatStringsSep "\n" (
    builtins.map (v: "    [${v}] = [==[${chapter.${v}}]==],") verses
  );
in {
  extraConfigLua = ''
    -- Scripture version identifier
    -- Derived at build time from git rev: ${gitRev}
    local _scripture = {
      book = [==[${bookName}]==],
      chapter = "${chapterKey}",
      verse = ${verseKey},
      text = [==[${verseText}]==],
      full_ref = [==[${fullRef}]==],
      rev = "${gitRev}",
      chapter_verses = {
    ${chapterLua}
      },
    }

    local _book_abbrevs = {
      ["Genesis"] = "Gen", ["Exodus"] = "Exo", ["Leviticus"] = "Lev",
      ["Numbers"] = "Num", ["Deuteronomy"] = "Deu", ["Joshua"] = "Jos",
      ["Judges"] = "Jdg", ["Ruth"] = "Rut", ["1 Samuel"] = "1 Sa",
      ["2 Samuel"] = "2 Sa", ["1 Kings"] = "1 Ki", ["2 Kings"] = "2 Ki",
      ["1 Chronicles"] = "1 Ch", ["2 Chronicles"] = "2 Ch", ["Ezra"] = "Ezr",
      ["Nehemiah"] = "Neh", ["Esther"] = "Est", ["Job"] = "Job",
      ["Psalms"] = "Psa", ["Proverbs"] = "Pro", ["Ecclesiastes"] = "Ecc",
      ["Song of Solomon"] = "Sol", ["Isaiah"] = "Isa", ["Jeremiah"] = "Jer",
      ["Lamentations"] = "Lam", ["Ezekiel"] = "Eze", ["Daniel"] = "Dan",
      ["Hosea"] = "Hos", ["Joel"] = "Joe", ["Amos"] = "Amo",
      ["Obadiah"] = "Oba", ["Jonah"] = "Jon", ["Micah"] = "Mic",
      ["Nahum"] = "Nah", ["Habakkuk"] = "Hab", ["Zephaniah"] = "Zep",
      ["Haggai"] = "Hag", ["Zechariah"] = "Zec", ["Malachi"] = "Mal",
      ["Matthew"] = "Mat", ["Mark"] = "Mar", ["Luke"] = "Luk",
      ["John"] = "Joh", ["Acts"] = "Act", ["Romans"] = "Rom",
      ["1 Corinthians"] = "1 Co", ["2 Corinthians"] = "2 Co",
      ["Galatians"] = "Gal", ["Ephesians"] = "Eph",
      ["Philippians"] = "Phi", ["Colossians"] = "Col",
      ["1 Thessalonians"] = "1 Th", ["2 Thessalonians"] = "2 Th",
      ["1 Timothy"] = "1 Ti", ["2 Timothy"] = "2 Ti", ["Titus"] = "Tit",
      ["Philemon"] = "Phm", ["Hebrews"] = "Heb", ["James"] = "Jam",
      ["1 Peter"] = "1 Pe", ["2 Peter"] = "2 Pe", ["1 John"] = "1 Jo",
      ["2 John"] = "2 Jo", ["3 John"] = "3 Jo", ["Jude"] = "Jud",
      ["Revelation"] = "Rev",
    }

    _scripture.short_ref = (_book_abbrevs[_scripture.book] or _scripture.book:sub(1, 3))
      .. " " .. _scripture.chapter .. ":" .. _scripture.verse

    -- Lualine component
    _G.scripture_lualine = function()
      return _scripture.short_ref
    end

    -- Word-wrap helper
    local function wrap_text(text, max_width, indent)
      indent = indent or ""
      local result = {}
      if #text <= max_width then
        table.insert(result, text)
      else
        local remaining = text
        while #remaining > max_width do
          local break_at = remaining:sub(1, max_width):match(".*()%s") or max_width
          table.insert(result, remaining:sub(1, break_at - 1))
          remaining = indent .. remaining:sub(break_at + 1)
        end
        if #remaining > 0 then
          table.insert(result, remaining)
        end
      end
      return result
    end

    -- :Scripture command - scrollable chapter view
    vim.api.nvim_create_user_command("Scripture", function()
      local width = math.min(80, math.floor(vim.o.columns * 0.8))
      local height = math.min(40, math.floor(vim.o.lines * 0.8))
      local text_width = width - 4 -- padding for verse numbers

      -- Build lines for every verse in the chapter
      local lines = {}
      local highlight_start = nil
      local highlight_end = nil

      -- Header
      table.insert(lines, _scripture.book .. " " .. _scripture.chapter .. " (ESV)")
      table.insert(lines, "Rev: " .. _scripture.rev)
      table.insert(lines, string.rep("─", width - 2))
      table.insert(lines, "")

      -- Get sorted verse numbers
      local verse_nums = {}
      for k in pairs(_scripture.chapter_verses) do
        table.insert(verse_nums, k)
      end
      table.sort(verse_nums)

      -- Render each verse
      for _, vnum in ipairs(verse_nums) do
        local vtext = _scripture.chapter_verses[vnum]
        local prefix = string.format("%3d  ", vnum)
        local continuation = "     "
        local wrapped = wrap_text(prefix .. vtext, text_width, continuation)

        if vnum == _scripture.verse then
          highlight_start = #lines
        end

        for _, wline in ipairs(wrapped) do
          table.insert(lines, wline)
        end

        if vnum == _scripture.verse then
          highlight_end = #lines - 1
        end

        table.insert(lines, "")
      end

      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.bo[buf].modifiable = false
      vim.bo[buf].buftype = "nofile"

      -- Highlight the selected verse
      local ns = vim.api.nvim_create_namespace("scripture_hl")
      if highlight_start and highlight_end then
        for i = highlight_start, highlight_end do
          vim.api.nvim_buf_add_highlight(buf, ns, "CurSearch", i, 0, -1)
        end
      end

      local row = math.floor((vim.o.lines - height) / 2)
      local col = math.floor((vim.o.columns - width) / 2)

      local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        border = "rounded",
        title = " " .. _scripture.full_ref .. " (ESV) ",
        title_pos = "center",
        style = "minimal",
      })

      -- Scroll to the selected verse
      if highlight_start then
        local center_line = math.floor((highlight_start + highlight_end) / 2)
        vim.api.nvim_win_set_cursor(win, { center_line + 1, 0 })
        vim.cmd("normal! zz")
      end

      local function close()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end
      vim.keymap.set("n", "q", close, { buffer = buf, silent = true })
      vim.keymap.set("n", "<Esc>", close, { buffer = buf, silent = true })
    end, { desc = "Show scripture chapter" })

    -- Startup notification
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        vim.defer_fn(function()
          vim.notify(
            _scripture.full_ref .. " - " .. _scripture.text,
            vim.log.levels.INFO
          )
        end, 500)
      end,
      once = true,
    })
  '';

  keymaps = [
    {
      mode = "n";
      key = "<leader>Sv";
      action = "<cmd>Scripture<CR>";
      options = {
        desc = "Show Verse";
        silent = true;
        noremap = true;
      };
    }
  ];
}
