<?php

namespace App\Filament\Resources;

use App\Filament\Resources\BattleResource\Pages;
use App\Models\Battle;
use App\Services\BattleService;
use Filament\Actions\Action;
use Filament\Forms;
use Filament\Notifications\Notification;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\Filter;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use BackedEnum;
use UnitEnum;
use Filament\Schemas\Schema;
use Filament\Schemas\Components\View as SchemaView;

class BattleResource extends Resource
{
    protected static ?string $model = Battle::class;

    protected static BackedEnum|string|null $navigationIcon = 'heroicon-o-bolt';

    protected static UnitEnum|string|null $navigationGroup = 'Jeu';

    protected static ?string $navigationLabel = 'Batailles';

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('status')
                    ->badge()
                    ->sortable(),
                TextColumn::make('mode')
                    ->badge()
                    ->sortable(),
                TextColumn::make('playerOne.displayName')
                    ->label('Joueur 1')
                    ->searchable(),
                TextColumn::make('playerTwo.displayName')
                    ->label('Joueur 2')
                    ->searchable(),
                TextColumn::make('player1Score')
                    ->label('Score J1')
                    ->sortable(),
                TextColumn::make('player2Score')
                    ->label('Score J2')
                    ->sortable(),
                TextColumn::make('winner')
                    ->label('Gagnant'),
                TextColumn::make('result')
                    ->badge(),
                TextColumn::make('createdAt')
                    ->dateTime()
                    ->label('Créée le')
                    ->sortable(),
            ])
            ->filters([
                SelectFilter::make('status')
                    ->options([
                        'waiting' => 'En attente',
                        'active' => 'Active',
                        'finished' => 'Terminée',
                    ]),
                SelectFilter::make('mode')
                    ->options([
                        'ranked' => 'Classée',
                        'friendly' => 'Amicale',
                    ]),
                Filter::make('created_at_range')
                    ->form([
                        Forms\Components\DatePicker::make('from')->label('Depuis'),
                        Forms\Components\DatePicker::make('until')->label('Jusqu\'au'),
                    ])
                    ->query(function ($query, array $data) {
                        return $query
                            ->when($data['from'] ?? null, fn ($q, $date) => $q->whereDate('createdAt', '>=', $date))
                            ->when($data['until'] ?? null, fn ($q, $date) => $q->whereDate('createdAt', '<=', $date));
                    }),
            ])
            ->actions([
                Action::make('view')
                    ->label('Voir')
                    ->icon('heroicon-o-eye')
                    ->url(fn (Battle $record) => static::getUrl('view', ['record' => $record]))
                    ->visible(fn () => auth()->user()?->canManageBattles() ?? false),
                Action::make('forceFinish')
                    ->label('Force finish')
                    ->icon('heroicon-o-flag')
                    ->requiresConfirmation()
                    ->action(function (Battle $record, BattleService $battleService) {
                        $battleService->forceFinish($record);

                        Notification::make()
                            ->title('Bataille clôturée')
                            ->body('Le score final et les trophées ont été recalculés.')
                            ->success()
                            ->send();
                    })
                    ->visible(fn () => auth()->user()?->canManageBattles()),
            ])
            ->headerActions([
                Action::make('cleanupBattles')
                    ->label('Nettoyer anciennes batailles')
                    ->icon('heroicon-o-trash')
                    ->color('danger')
                    ->requiresConfirmation()
                    ->action(function (BattleService $battleService) {
                        $result = $battleService->cleanupOldBattles();

                        Notification::make()
                            ->title('Nettoyage effectué')
                            ->body("En attente supprimées: {$result['waiting']} • Terminées supprimées: {$result['finished']}")
                            ->success()
                            ->send();
                    })
                    ->visible(fn () => auth()->user()?->canManageBattles()),
            ])
            ->defaultSort('createdAt', 'desc');
    }

    public static function infolist(Schema $schema): Schema
    {
        return $schema
            ->components([
                SchemaView::make('filament.resources.battles.detail')
                    ->viewData(fn ($record) => ['battle' => $record]),
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListBattles::route('/'),
            'view' => Pages\ViewBattle::route('/{record}'),
        ];
    }

    public static function canViewAny(): bool
    {
        return auth()->user()?->canManageBattles() ?? false;
    }

    public static function shouldRegisterNavigation(): bool
    {
        return self::canViewAny();
    }
}

