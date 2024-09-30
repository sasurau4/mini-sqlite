describe 'database' do
  before do
    `rm -f ./test.db`
  end

  def run_script(commands)
    raw_output = nil
    IO.popen('./db test.db', 'r+') do |pipe|
      commands.each do |command|
        pipe.puts command
      rescue Errno::EPIPE
        break
      end

      pipe.close_write

      # Read entire output
      raw_output = pipe.gets(nil)
    end
    raw_output.split("\n")
  end

  it 'inserts and retrieves a row' do
    result = run_script([
                          'insert 1 user1 person1@example.com',
                          'select',
                          '.exit'
                        ])
    expect(result).to match_array([
                                    'db > Executed.',
                                    'db > (1, user1, person1@example.com)',
                                    'Executed.',
                                    'db > '
                                  ])
  end

  it 'prints error message when table is full' do
    script = (1..1401).map do |i|
      "insert #{i} user#{i} person#{i}@example.com"
    end
    script << '.exit'
    result = run_script(script)
    expect(result.last(2)).to match_array([
                                            'db > Executed.',
                                            'db > Tried to fetch page number out of bounds. 101 > 100'
                                          ])
  end

  it 'allows inserting strings that are the maximum length' do
    long_username = 'a' * 32
    long_email = 'a' * 255
    script = [
      "insert 1 #{long_username} #{long_email}",
      'select',
      '.exit'
    ]
    result = run_script(script)
    expect(result).to match_array([
                                    'db > Executed.',
                                    "db > (1, #{long_username}, #{long_email})",
                                    'Executed.',
                                    'db > '
                                  ])
  end

  it 'prints error message if strings are too long' do
    long_username = 'a' * 33
    long_email = 'a' * 256
    script = [
      "insert 1 #{long_username} #{long_email}",
      'select',
      '.exit'
    ]
    result = run_script(script)
    expect(result).to match_array([
                                    'db > String is too long.',
                                    'db > Executed.',
                                    'db > '
                                  ])
  end

  it 'prints an error message if id is negative' do
    script = [
      'insert -1 cstack foo@bar.com',
      'select',
      '.exit'
    ]
    result = run_script(script)
    expect(result).to match_array([
                                    'db > ID must be positive.',
                                    'db > Executed.',
                                    'db > '
                                  ])
  end

  it 'keeps data after closing connection' do
    result1 = run_script([
                           'insert 1 user1 person1@example.com',
                           '.exit'
                         ])
    expect(result1).to match_array([
                                     'db > Executed.',
                                     'db > '
                                   ])
    result2 = run_script([
                           'select',
                           '.exit'
                         ])
    expect(result2).to match_array([
                                     'db > (1, user1, person1@example.com)',
                                     'Executed.',
                                     'db > '
                                   ])
  end

  it 'prints constans' do
    script = [
      '.constants',
      '.exit'
    ]
    result = run_script(script)

    expect(result).to match_array([
                                    'db > Constants:',
                                    'ROW_SIZE: 293',
                                    'COMMON_NODE_HEADER_SIZE: 6',
                                    'LEAF_NODE_HEADER_SIZE: 14',
                                    'LEAF_NODE_CELL_SIZE: 297',
                                    'LEAF_NODE_SPACE_FOR_CELLS: 4082',
                                    'LEAF_NODE_MAX_CELLS: 13',
                                    'db > '
                                  ])
  end

  it 'allows printing out the structure of a one-node btree' do
    script = [3, 1, 2].map do |i|
      "insert #{i} user#{i} person#{i}@example.com"
    end
    script << '.btree'
    script << '.exit'
    result = run_script(script)

    expect(result).to match_array([
                                    'db > Executed.',
                                    'db > Executed.',
                                    'db > Executed.',
                                    'db > Tree:',
                                    '- leaf (size 3)',
                                    '  - 1',
                                    '  - 2',
                                    '  - 3',
                                    'db > '
                                  ])
  end

  it 'allows printing out the structure of a 3-leaf-node btree' do
    script = (1..14).map do |i|
      "insert #{i} user#{i} person#{i}@example.com"
    end
    script << '.btree'
    script << 'insert 15 user15 person15@example.com'
    script << '.exit'
    result = run_script(script)

    expect(result[14...(result.length)]).to match_array([
                                                          'db > Tree:',
                                                          '- internal (size 1)',
                                                          '  - leaf (size 7)',
                                                          '    - 1',
                                                          '    - 2',
                                                          '    - 3',
                                                          '    - 4',
                                                          '    - 5',
                                                          '    - 6',
                                                          '    - 7',
                                                          '  - key 7',
                                                          '  - leaf (size 7)',
                                                          '    - 8',
                                                          '    - 9',
                                                          '    - 10',
                                                          '    - 11',
                                                          '    - 12',
                                                          '    - 13',
                                                          '    - 14',
                                                          'db > Executed.',
                                                          'db > '
                                                        ])
  end

  it 'prints an error message if there is a duplicate id' do
    script = [
      'insert 1 user1 person1@example.com',
      'insert 1 user1 person1@example.com',
      'select',
      '.exit'
    ]
    result = run_script(script)
    expect(result).to match_array([
                                    'db > Executed.',
                                    'db > Error: Duplicate key.',
                                    'db > (1, user1, person1@example.com)',
                                    'Executed.',
                                    'db > '
                                  ])
  end

  it 'prints all rows in a multi-level tree' do
    script = []
    (1..15).each do |i|
      script << "insert #{i} user#{i} person#{i}@example.com"
    end
    script << 'select'
    script << '.exit'
    result = run_script(script)

    expect(result[15...result.length]).to match_array([
                                                        'db > (1, user1, person1@example.com)',
                                                        '(2, user2, person2@example.com)',
                                                        '(3, user3, person3@example.com)',
                                                        '(4, user4, person4@example.com)',
                                                        '(5, user5, person5@example.com)',
                                                        '(6, user6, person6@example.com)',
                                                        '(7, user7, person7@example.com)',
                                                        '(8, user8, person8@example.com)',
                                                        '(9, user9, person9@example.com)',
                                                        '(10, user10, person10@example.com)',
                                                        '(11, user11, person11@example.com)',
                                                        '(12, user12, person12@example.com)',
                                                        '(13, user13, person13@example.com)',
                                                        '(14, user14, person14@example.com)',
                                                        '(15, user15, person15@example.com)',
                                                        'Executed.',
                                                        'db > '
                                                      ])
  end

  it 'allows printing out the structure of a 4-leaf-node btree' do
    script = []
    pseudorandom_numbers = [
      18,
      7,
      10,
      29,
      23,
      4,
      14,
      30,
      15,
      26,
      22,
      19,
      2,
      1,
      21,
      11,
      6,
      20,
      5,
      8,
      9,
      3,
      12,
      27,
      17,
      16,
      13,
      24,
      25,
      28
    ]
    pseudorandom_numbers.each do |i|
      script << "insert #{i} user#{i} person#{i}@example.com"
    end
    script << '.btree'
    script << '.exit'

    result = run_script(script)

    expect(result[30...(result.length)]).to match_array([
                                                          'db > Tree:',
                                                          '- internal (size 3)',
                                                          '  - leaf (size 7)',
                                                          '    - 1',
                                                          '    - 2',
                                                          '    - 3',
                                                          '    - 4',
                                                          '    - 5',
                                                          '    - 6',
                                                          '    - 7',
                                                          '  - key 7',
                                                          '  - leaf (size 8)',
                                                          '    - 8',
                                                          '    - 9',
                                                          '    - 10',
                                                          '    - 11',
                                                          '    - 12',
                                                          '    - 13',
                                                          '    - 14',
                                                          '    - 15',
                                                          '  - key 15',
                                                          '  - leaf (size 7)',
                                                          '    - 16',
                                                          '    - 17',
                                                          '    - 18',
                                                          '    - 19',
                                                          '    - 20',
                                                          '    - 21',
                                                          '    - 22',
                                                          '  - key 22',
                                                          '  - leaf (size 8)',
                                                          '    - 23',
                                                          '    - 24',
                                                          '    - 25',
                                                          '    - 26',
                                                          '    - 27',
                                                          '    - 28',
                                                          '    - 29',
                                                          '    - 30',
                                                          'db > '
                                                        ])
  end

  it 'allows printing out the structure of a 7-leaf-node btree' do
    script = []
    pseudorandom_numbers = [
      58,
      56,
      8,
      54,
      77,
      7,
      25,
      71,
      13,
      22,
      53,
      51,
      59,
      32,
      36,
      79,
      10,
      33,
      20,
      4,
      35,
      76,
      49,
      24,
      70,
      48,
      39,
      15,
      47,
      30,
      86,
      31,
      68,
      37,
      66,
      63,
      40,
      78,
      19,
      46,
      14,
      81,
      72,
      6,
      50,
      85,
      67,
      2,
      55,
      69,
      5,
      65,
      52,
      1,
      29,
      9,
      43,
      75,
      21,
      82,
      12,
      18,
      60,
      44
    ]
    pseudorandom_numbers.each do |i|
      script << "insert #{i} user#{i} person#{i}@example.com"
    end
    script << '.btree'
    script << '.exit'

    result = run_script(script)

    expect(result[64...(result.length)]).to match_array([
                                                          'db > Tree:',
                                                          '- internal (size 1)',
                                                          '  - internal (size 2)',
                                                          '    - leaf (size 7)',
                                                          '      - 1',
                                                          '      - 2',
                                                          '      - 4',
                                                          '      - 5',
                                                          '      - 6',
                                                          '      - 7',
                                                          '      - 8',
                                                          '    - key 8',
                                                          '    - leaf (size 11)',
                                                          '      - 9',
                                                          '      - 10',
                                                          '      - 12',
                                                          '      - 13',
                                                          '      - 14',
                                                          '      - 15',
                                                          '      - 18',
                                                          '      - 19',
                                                          '      - 20',
                                                          '      - 21',
                                                          '      - 22',
                                                          '    - key 22',
                                                          '    - leaf (size 8)',
                                                          '      - 24',
                                                          '      - 25',
                                                          '      - 29',
                                                          '      - 30',
                                                          '      - 31',
                                                          '      - 32',
                                                          '      - 33',
                                                          '      - 35',
                                                          '  - key 35',
                                                          '  - internal (size 3)',
                                                          '    - leaf (size 12)',
                                                          '      - 36',
                                                          '      - 37',
                                                          '      - 39',
                                                          '      - 40',
                                                          '      - 43',
                                                          '      - 44',
                                                          '      - 46',
                                                          '      - 47',
                                                          '      - 48',
                                                          '      - 49',
                                                          '      - 50',
                                                          '      - 51',
                                                          '    - key 51',
                                                          '    - leaf (size 11)',
                                                          '      - 52',
                                                          '      - 53',
                                                          '      - 54',
                                                          '      - 55',
                                                          '      - 56',
                                                          '      - 58',
                                                          '      - 59',
                                                          '      - 60',
                                                          '      - 63',
                                                          '      - 65',
                                                          '      - 66',
                                                          '    - key 66',
                                                          '    - leaf (size 7)',
                                                          '      - 67',
                                                          '      - 68',
                                                          '      - 69',
                                                          '      - 70',
                                                          '      - 71',
                                                          '      - 72',
                                                          '      - 75',
                                                          '    - key 75',
                                                          '    - leaf (size 8)',
                                                          '      - 76',
                                                          '      - 77',
                                                          '      - 78',
                                                          '      - 79',
                                                          '      - 81',
                                                          '      - 82',
                                                          '      - 85',
                                                          '      - 86',
                                                          'db > '
                                                        ])
  end
end
