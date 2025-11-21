<?php

namespace App\Filament\Resources;

use App\Filament\Resources\LevelResource\Pages;
use App\Models\Level;
use App\Services\LevelService;
use Filament\Forms;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Actions\Action;
use Filament\Actions\DeleteBulkAction;
use Filament\Tables;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;
use Symfony\Component\HttpFoundation\StreamedResponse;
use Livewire\Features\SupportFileUploads\TemporaryUploadedFile;
use Filament\Schemas\Schema;
use BackedEnum;
use UnitEnum;

class LevelResource extends Resource
{
    protected static ?string $model = Level::class;

    protected static BackedEnum|string|null $navigationIcon = 'heroicon-o-map';

    protected static UnitEnum|string|null $navigationGroup = 'Contenu';

    protected static ?string $navigationLabel = 'Niveaux';

    public static function form(Schema $schema): Schema
    {
        return $schema
            ->schema([
                Forms\Components\TextInput::make('name')
                    ->required()
                    ->maxLength(191),
                Forms\Components\TextInput::make('code')
                    ->required()
                    ->maxLength(191),
                Forms\Components\TextInput::make('codeLength')
                    ->numeric()
                    ->required(),
                Forms\Components\Textarea::make('instruction')
                    ->rows(6)
                    ->required(),
                Forms\Components\TextInput::make('pointsReward')
                    ->numeric()
                    ->required(),
                Forms\Components\Toggle::make('isLocked')
                    ->label('Verrouillé'),
                Forms\Components\TextInput::make('timeLimit')
                    ->numeric(),
                Forms\Components\Repeater::make('additionalHints')
                    ->schema([
                        Forms\Components\Textarea::make('hint')
                            ->label('Indice')
                            ->rows(2),
                    ])
                    ->default([])
                    ->collapsible(),
                Forms\Components\TextInput::make('hintCost')
                    ->numeric()
                    ->minValue(0),
            ])
            ->columns(2);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('id')
                    ->sortable(),
                TextColumn::make('name')
                    ->searchable()
                    ->sortable(),
                TextColumn::make('code')
                    ->badge(),
                IconColumn::make('isLocked')
                    ->label('Verrouillé')
                    ->boolean(),
                TextColumn::make('pointsReward')
                    ->label('Points'),
                TextColumn::make('timeLimit')
                    ->label('Limite (s)'),
            ])
            ->actions([
                self::viewLevelAction(),
                self::editLevelAction(),
                self::deleteLevelAction(),
            ])
            ->bulkActions([
                DeleteBulkAction::make(),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListLevels::route('/'),
            'create' => Pages\CreateLevel::route('/create'),
            'view' => Pages\ViewLevel::route('/{record}'),
            'edit' => Pages\EditLevel::route('/{record}/edit'),
        ];
    }

    public static function canViewAny(): bool
    {
        return auth()->user()?->canManageLevels() ?? false;
    }

    public static function shouldRegisterNavigation(): bool
    {
        return self::canViewAny();
    }

    public static function importAction(): Action
    {
        return Action::make('importLevels')
            ->label('Importer JSON')
            ->icon('heroicon-o-arrow-down-on-square-stack')
            ->form([
                Forms\Components\FileUpload::make('file')
                    ->label('levels.json')
                    ->required()
                    ->acceptedFileTypes(['application/json', 'text/json'])
                    ->storeFiles(false),
            ])
            ->action(function (array $data, LevelService $levelService) {
                /** @var TemporaryUploadedFile|null $file */
                $file = $data['file'];

                if (! $file instanceof TemporaryUploadedFile) {
                    throw new \RuntimeException('Fichier JSON manquant.');
                }

                $payload = json_decode($file->get(), true, flags: JSON_THROW_ON_ERROR);

                $levelService->importFromArray($payload);

                Notification::make()
                    ->title('Niveaux importés')
                    ->success()
                    ->send();
            })
            ->visible(fn () => auth()->user()?->canManageLevels());
    }

    public static function exportAction(): Action
    {
        return Action::make('exportLevels')
            ->label('Exporter JSON')
            ->icon('heroicon-o-arrow-up-tray')
            ->action(function (LevelService $levelService): StreamedResponse {
                $content = $levelService->exportAsJsonString();

                return response()->streamDownload(
                    fn () => print $content,
                    'levels.json',
                    [
                        'Content-Type' => 'application/json',
                    ],
                );
            })
            ->visible(fn () => auth()->user()?->canManageLevels());
    }

    public static function resetFromSeedAction(): Action
    {
        return Action::make('resetLevels')
            ->label('Reset depuis seed')
            ->icon('heroicon-o-arrow-path')
            ->color('danger')
            ->requiresConfirmation()
            ->action(function (LevelService $levelService) {
                $levelService->resetFromSeed();

                Notification::make()
                    ->title('Niveaux réinitialisés')
                    ->success()
                    ->send();
            })
            ->visible(fn () => auth()->user()?->canManageLevels());
    }

    public static function normalizePayload(array $data): array
    {
        $data['codeLength'] = $data['codeLength'] ?? strlen((string) ($data['code'] ?? ''));

        return $data;
    }

    protected static function viewLevelAction(): Action
    {
        return Action::make('view')
            ->label('Voir')
            ->icon('heroicon-o-eye')
            ->url(fn (Level $record) => static::getUrl('view', ['record' => $record]))
            ->visible(fn () => auth()->user()?->canManageLevels() ?? false);
    }

    protected static function editLevelAction(): Action
    {
        return Action::make('edit')
            ->label('Modifier')
            ->icon('heroicon-o-pencil-square')
            ->color('primary')
            ->url(fn (Level $record) => static::getUrl('edit', ['record' => $record]))
            ->visible(fn () => auth()->user()?->canManageLevels() ?? false);
    }

    protected static function deleteLevelAction(): Action
    {
        return Action::make('delete')
            ->label('Supprimer')
            ->icon('heroicon-o-trash')
            ->color('danger')
            ->requiresConfirmation()
            ->action(fn (Level $record) => $record->delete())
            ->visible(fn () => auth()->user()?->canManageLevels() ?? false);
    }
}

