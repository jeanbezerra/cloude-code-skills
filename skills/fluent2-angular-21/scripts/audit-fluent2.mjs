#!/usr/bin/env node

import { access, readFile, readdir } from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const SOURCE_EXTENSIONS = new Set(['.ts', '.html', '.scss', '.css']);
const IGNORED_DIRECTORIES = new Set([
  '.angular',
  '.git',
  'coverage',
  'dist',
  'node_modules',
]);

function parseArguments(argv) {
  const options = {
    project: process.cwd(),
    source: 'src',
    strict: false,
    json: false,
    help: false,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    switch (argument) {
      case '--project':
        options.project = argv[index + 1];
        index += 1;
        break;
      case '--source':
        options.source = argv[index + 1];
        index += 1;
        break;
      case '--strict':
        options.strict = true;
        break;
      case '--json':
        options.json = true;
        break;
      case '--help':
      case '-h':
        options.help = true;
        break;
      default:
        throw new Error(`Argumento desconhecido: ${argument}`);
    }
  }

  if (!options.project || !options.source) {
    throw new Error('Os argumentos --project e --source precisam de um valor.');
  }

  return options;
}

function printHelp() {
  process.stdout.write(`Uso:
  node audit-fluent2.mjs --project <diretório> [--source src] [--strict] [--json]

Opções:
  --project  Raiz do projeto Angular. O padrão é o diretório atual.
  --source   Diretório de fontes relativo ao projeto. O padrão é src.
  --strict   Trata avisos como falha.
  --json     Emite resultado estruturado em JSON.
`);
}

async function pathExists(targetPath) {
  try {
    await access(targetPath);
    return true;
  } catch {
    return false;
  }
}

async function readJson(targetPath) {
  return JSON.parse(await readFile(targetPath, 'utf8'));
}

async function collectSourceFiles(directory) {
  if (!(await pathExists(directory))) {
    return [];
  }

  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    if (entry.isDirectory()) {
      if (!IGNORED_DIRECTORIES.has(entry.name)) {
        files.push(...(await collectSourceFiles(path.join(directory, entry.name))));
      }
      continue;
    }

    if (entry.isFile() && SOURCE_EXTENSIONS.has(path.extname(entry.name))) {
      files.push(path.join(directory, entry.name));
    }
  }
  return files;
}

function parseMajorVersion(version) {
  if (typeof version !== 'string') {
    return null;
  }
  const match = version.match(/\d+/);
  return match ? Number.parseInt(match[0], 10) : null;
}

function allDependencies(packageJson) {
  return {
    ...(packageJson.dependencies ?? {}),
    ...(packageJson.devDependencies ?? {}),
    ...(packageJson.peerDependencies ?? {}),
  };
}

async function loadKnownFluentTags(projectPath, warnings) {
  const packagePath = path.join(projectPath, 'node_modules', '@fluentui', 'web-components');
  const manifestPath = path.join(packagePath, 'custom-elements.json');
  const knownTags = new Set();

  if (await pathExists(manifestPath)) {
    try {
      const manifest = await readJson(manifestPath);
      for (const module of manifest.modules ?? []) {
        for (const declaration of module.declarations ?? []) {
          if (declaration.tagName) {
            knownTags.add(declaration.tagName);
          }
        }
      }
    } catch (error) {
      warnings.push({
        code: 'cem-read',
        message: `Não foi possível interpretar o Custom Elements Manifest: ${error.message}`,
      });
    }
  } else {
    warnings.push({
      code: 'cem-missing',
      message: 'custom-elements.json não foi encontrado na instalação local.',
    });
  }

  const esmPath = path.join(packagePath, 'dist', 'esm');
  if (await pathExists(esmPath)) {
    for (const entry of await readdir(esmPath, { withFileTypes: true })) {
      if (entry.isDirectory()) {
        const moduleFile = path.join(esmPath, entry.name, `${entry.name}.js`);
        const defineFile = path.join(esmPath, entry.name, 'define.js');
        if ((await pathExists(moduleFile)) || (await pathExists(defineFile))) {
          knownTags.add(`fluent-${entry.name}`);
        }
      }
    }
  }

  return knownTags;
}

function relativeFile(projectPath, filePath) {
  return path.relative(projectPath, filePath).split(path.sep).join('/');
}

async function auditProject(options) {
  const projectPath = path.resolve(options.project);
  const sourcePath = path.resolve(projectPath, options.source);
  const packageJsonPath = path.join(projectPath, 'package.json');
  const errors = [];
  const warnings = [];

  if (!(await pathExists(packageJsonPath))) {
    throw new Error(`package.json não encontrado em ${projectPath}`);
  }

  const packageJson = await readJson(packageJsonPath);
  const dependencies = allDependencies(packageJson);
  const angularVersion = dependencies['@angular/core'];
  const angularMajor = parseMajorVersion(angularVersion);

  if (angularMajor === null) {
    warnings.push({ code: 'angular-missing', message: '@angular/core não foi encontrado.' });
  } else if (angularMajor < 21) {
    errors.push({
      code: 'angular-version',
      message: `Angular ${angularVersion} é inferior ao requisito Angular 21+ da skill.`,
    });
  }

  for (const packageName of Object.keys(dependencies)) {
    if (packageName.startsWith('@fluentui/react')) {
      errors.push({
        code: 'react-runtime',
        message: `Dependência React incompatível com esta integração Angular: ${packageName}`,
      });
    }
  }

  const hasWebComponents = Boolean(dependencies['@fluentui/web-components']);
  if (!hasWebComponents) {
    warnings.push({
      code: 'web-components-missing',
      message: '@fluentui/web-components não está instalado; confirme se a tarefa usa somente HTML/custom.',
    });
  }

  const sourceFiles = await collectSourceFiles(sourcePath);
  if (sourceFiles.length === 0) {
    warnings.push({
      code: 'source-empty',
      message: `Nenhum arquivo auditável encontrado em ${sourcePath}.`,
    });
  }

  const sourceEntries = await Promise.all(
    sourceFiles.map(async (filePath) => ({
      filePath,
      content: await readFile(filePath, 'utf8'),
    })),
  );
  const combinedSource = sourceEntries.map((entry) => entry.content).join('\n');

  const forbiddenImportPattern = /(?:from\s+|import\s*\(?)['"](@fluentui\/react[^'"]*)['"]/g;
  for (const entry of sourceEntries) {
    for (const match of entry.content.matchAll(forbiddenImportPattern)) {
      errors.push({
        code: 'react-import',
        file: relativeFile(projectPath, entry.filePath),
        message: `Import React proibido: ${match[1]}`,
      });
    }
  }

  const alternativeIconPattern = /['"](@fortawesome\/[^'"]+|lucide(?:-angular)?|material-icons|heroicons[^'"]*)['"]/g;
  for (const entry of sourceEntries) {
    for (const match of entry.content.matchAll(alternativeIconPattern)) {
      warnings.push({
        code: 'icon-library',
        file: relativeFile(projectPath, entry.filePath),
        message: `Biblioteca de ícones não Fluent encontrada: ${match[1]}`,
      });
    }
  }

  const usedTags = new Set(combinedSource.match(/<fluent-[a-z0-9-]+/g)?.map((tag) => tag.slice(1)) ?? []);
  if (hasWebComponents && usedTags.size > 0) {
    const knownTags = await loadKnownFluentTags(projectPath, warnings);
    for (const tag of usedTags) {
      if (!knownTags.has(tag)) {
        errors.push({
          code: 'unknown-tag',
          message: `A tag <${tag}> não existe no CEM nem nos módulos da versão instalada.`,
        });
      }
    }

    const importsAllComponents = /@fluentui\/web-components\/(?:web-components(?:-all)?)(?:\.min)?\.js/.test(
      combinedSource,
    );
    if (!importsAllComponents) {
      const registeredModules = new Set(
        [...combinedSource.matchAll(/@fluentui\/web-components\/([a-z0-9-]+)\.js/g)].map(
          (match) => match[1],
        ),
      );
      for (const tag of usedTags) {
        const moduleName = tag.replace(/^fluent-/, '');
        if (!registeredModules.has(moduleName)) {
          warnings.push({
            code: 'registration-missing',
            message: `<${tag}> é usado, mas nenhum import individual de ${moduleName}.js foi localizado.`,
          });
        }
      }
    }

    if (!/\bsetTheme\s*\(/.test(combinedSource)) {
      warnings.push({
        code: 'theme-missing',
        message: 'Web Components são usados, mas nenhuma chamada setTheme(...) foi localizada nas fontes.',
      });
    }
  }

  const rawColorFiles = [];
  for (const entry of sourceEntries) {
    if (!['.scss', '.css'].includes(path.extname(entry.filePath))) {
      continue;
    }
    const withoutComments = entry.content.replace(/\/\*[\s\S]*?\*\//g, '');
    if (/(^|[^\w-])#[0-9a-fA-F]{3,8}\b/.test(withoutComments)) {
      rawColorFiles.push(relativeFile(projectPath, entry.filePath));
    }
  }
  if (rawColorFiles.length > 0) {
    warnings.push({
      code: 'raw-colors',
      message: `Cores hexadecimais exigem revisão de token: ${rawColorFiles.slice(0, 5).join(', ')}${rawColorFiles.length > 5 ? '…' : ''}`,
    });
  }

  return {
    project: projectPath,
    angular: angularVersion ?? null,
    filesScanned: sourceFiles.length,
    usedFluentTags: [...usedTags].sort(),
    errors,
    warnings,
  };
}

function printHumanResult(result) {
  process.stdout.write(`Fluent 2 Angular audit\nProjeto: ${result.project}\n`);
  process.stdout.write(`Angular: ${result.angular ?? 'não detectado'}\n`);
  process.stdout.write(`Arquivos analisados: ${result.filesScanned}\n`);
  for (const issue of result.errors) {
    process.stdout.write(`[ERRO] ${issue.code}${issue.file ? ` (${issue.file})` : ''}: ${issue.message}\n`);
  }
  for (const issue of result.warnings) {
    process.stdout.write(`[AVISO] ${issue.code}${issue.file ? ` (${issue.file})` : ''}: ${issue.message}\n`);
  }
  process.stdout.write(
    `Resultado: ${result.errors.length} erro(s), ${result.warnings.length} aviso(s).\n`,
  );
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  if (options.help) {
    printHelp();
    return;
  }

  const result = await auditProject(options);
  if (options.json) {
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  } else {
    printHumanResult(result);
  }

  if (result.errors.length > 0 || (options.strict && result.warnings.length > 0)) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  process.stderr.write(`Falha no auditor Fluent 2 Angular: ${error.message}\n`);
  process.exitCode = 1;
});
