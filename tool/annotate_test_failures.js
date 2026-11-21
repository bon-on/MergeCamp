// Turns failed tests in a `flutter test --file-reporter json:<file>` result into
// GitHub error annotations. Job logs need a signed-in account to read, while
// annotations are readable through the public API.
const fs = require('fs');

const file = process.argv[2] || 'test-results.json';
if (!fs.existsSync(file)) {
  console.log(`::error title=Test results missing::${file} was not written`);
  process.exit(0);
}

const escape = (s) =>
  s.replace(/%/g, '%25').replace(/\r/g, '%0D').replace(/\n/g, '%0A');
const escapeProperty = (s) => escape(s).replace(/:/g, '%3A').replace(/,/g, '%2C');

const tests = {};
const errors = {};
const prints = {};
for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
  if (!line.trim()) continue;
  let event;
  try {
    event = JSON.parse(line);
  } catch {
    continue;
  }
  if (event.type === 'testStart') tests[event.test.id] = event.test;
  if (event.type === 'print') {
    (prints[event.testID] ||= []).push(event.message);
  }
  if (event.type === 'error') {
    (errors[event.testID] ||= []).push(event.error);
  }
  if (
    event.type === 'testDone' &&
    event.result !== 'success' &&
    !event.skipped
  ) {
    const test = tests[event.testID] || {};
    const url = (test.root_url || test.url || '').replace(/^.*\/test\//, 'test/');
    const title = `${url} | ${test.name || 'unknown test'}`.slice(0, 250);
    const message = (errors[event.testID] || ['(no error text)'])
      .join('\n')
      .slice(0, 4000);
    console.log(`::error title=${escapeProperty(title)}::${escape(message)}`);
  }
}
