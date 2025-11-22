<?php

namespace App\Filament\Resources;

use App\Filament\Resources\GameConfigResource\Pages;
use App\Models\GameConfig;
use Filament\Forms;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables;
use Filament\Tables\Table;

class GameConfigResource extends Resource
{
    protected static ?string $model = GameConfig::class;

    protected static ?string $navigationIcon = 'heroicon-o-cog';

    protected static ?string $navigationLabel = 'Configuration Jeu';

    protected static ?string $navigationGroup = 'Système';

    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                Forms\Components\Section::make('Paramètres Duel')
                    ->schema([
                        Forms\Components\TextInput::make('trophies_win')
                            ->label('Trophées gagnés (Victoire)')
                            ->numeric()
                            ->default(100)
                            ->required(),
                        Forms\Components\TextInput::make('trophies_loss')
                            ->label('Trophées perdus (Défaite)')
                            ->numeric()
                            ->default(100)
                            ->required(),
                        Forms\Components\TextInput::make('trophies_draw')
                            ->label('Trophées gagnés (Match nul)')
                            ->numeric()
                            ->default(10)
                            ->required(),
                        Forms\Components\TextInput::make('game_timer')
                            ->label('Durée du duel (secondes)')
                            ->numeric()
                            ->default(300)
                            ->required(),
                        Forms\Components\TextInput::make('question_timer')
                            ->label('Temps par question (secondes)')
                            ->numeric()
                            ->default(30)
                            ->required(),
                    ])->columns(2),

                Forms\Components\Section::make('Mises à jour & Maintenance')
                    ->schema([
                        Forms\Components\TextInput::make('min_version_android')
                            ->label('Version Min Android')
                            ->default('1.0.0')
                            ->required(),
                        Forms\Components\TextInput::make('min_version_ios')
                            ->label('Version Min iOS')
                            ->default('1.0.0')
                            ->required(),
                        Forms\Components\Toggle::make('force_update')
                            ->label('Forcer la mise à jour')
                            ->helperText('Si activé, les utilisateurs en dessous de la version min seront bloqués.'),
                        Forms\Components\Toggle::make('maintenance_mode')
                            ->label('Mode Maintenance')
                            ->helperText('Si activé, l\'accès au jeu est bloqué.'),
                    ])->columns(2),
            ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                Tables\Columns\TextColumn::make('updated_at')
                    ->label('Dernière modification')
                    ->dateTime(),
                Tables\Columns\BooleanColumn::make('force_update')
                    ->label('Force Update'),
                Tables\Columns\BooleanColumn::make('maintenance_mode')
                    ->label('Maintenance'),
                Tables\Columns\TextColumn::make('min_version_android')
                    ->label('Min Android'),
            ])
            ->filters([
                //
            ])
            ->actions([
                Tables\Actions\EditAction::make(),
            ])
            ->bulkActions([
                //
            ]);
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListGameConfigs::route('/'),
            'create' => Pages\CreateGameConfig::route('/create'),
            'edit' => Pages\EditGameConfig::route('/{record}/edit'),
        ];
    }
}
