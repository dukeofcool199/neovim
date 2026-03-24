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
    .${c};
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
in {
  extraConfigLua = ''
    -- Scripture version identifier
    -- Derived at build time from git rev: ${gitRev}
    local _scripture = {
      book = [==[${bookName}]==],
      chapter = "${chapterKey}",
      verse = "${verseKey}",
      text = [==[${verseText}]==],
      full_ref = [==[${fullRef}]==],
      rev = "${gitRev}",
    }

    local _book_abbrevs = {
      ["Genesis"] = "Gen", ["Exodus"] = "Exo", ["Leviticus"] = "Lev",
      ["Numbers"] = "Num", ["Deuteronomy"] = "Deu", ["Joshua"] = "Jos",
      ["Judges"] = "Jdg", ["Ruth"] = "Rut", ["1 Samuel"] = "1Sa",
      ["2 Samuel"] = "2Sa", ["1 Kings"] = "1Ki", ["2 Kings"] = "2Ki",
      ["1 Chronicles"] = "1Ch", ["2 Chronicles"] = "2Ch", ["Ezra"] = "Ezr",
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
      ["1 Corinthians"] = "1Co", ["2 Corinthians"] = "2Co",
      ["Galatians"] = "Gal", ["Ephesians"] = "Eph",
      ["Philippians"] = "Phi", ["Colossians"] = "Col",
      ["1 Thessalonians"] = "1Th", ["2 Thessalonians"] = "2Th",
      ["1 Timothy"] = "1Ti", ["2 Timothy"] = "2Ti", ["Titus"] = "Tit",
      ["Philemon"] = "Phm", ["Hebrews"] = "Heb", ["James"] = "Jam",
      ["1 Peter"] = "1Pe", ["2 Peter"] = "2Pe", ["1 John"] = "1Jo",
      ["2 John"] = "2Jo", ["3 John"] = "3Jo", ["Jude"] = "Jud",
      ["Revelation"] = "Rev",
    }

    _scripture.short_ref = (_book_abbrevs[_scripture.book] or _scripture.book:sub(1, 3))
      .. " " .. _scripture.chapter .. ":" .. _scripture.verse

    -- Lualine component
    _G.scripture_lualine = function()
      return _scripture.short_ref
    end

    -- :Scripture command - floating window
    vim.api.nvim_create_user_command("Scripture", function()
      local header = _scripture.full_ref .. " (ESV)"
      local lines = { header, "", _scripture.text, "", "Rev: " .. _scripture.rev }

      -- Word-wrap
      local max_width = math.min(72, math.floor(vim.o.columns * 0.7))
      local wrapped = {}
      for _, line in ipairs(lines) do
        if #line <= max_width then
          table.insert(wrapped, line)
        else
          local remaining = line
          while #remaining > max_width do
            local break_at = remaining:sub(1, max_width):match(".*()%s") or max_width
            table.insert(wrapped, remaining:sub(1, break_at - 1))
            remaining = remaining:sub(break_at + 1)
          end
          if #remaining > 0 then
            table.insert(wrapped, remaining)
          end
        end
      end

      local width = 0
      for _, l in ipairs(wrapped) do
        width = math.max(width, #l)
      end
      width = math.min(width + 2, vim.o.columns - 4)
      local height = #wrapped

      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, wrapped)
      vim.bo[buf].modifiable = false
      vim.bo[buf].buftype = "nofile"

      local row = math.floor((vim.o.lines - height) / 2)
      local col = math.floor((vim.o.columns - width) / 2)

      local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        border = "rounded",
        title = " Scripture ",
        title_pos = "center",
        style = "minimal",
      })

      local function close()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end
      vim.keymap.set("n", "q", close, { buffer = buf, silent = true })
      vim.keymap.set("n", "<Esc>", close, { buffer = buf, silent = true })
    end, { desc = "Show scripture version identifier" })

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
