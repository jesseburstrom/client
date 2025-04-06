// backend/src/models/BoardCell.ts

export class BoardCell {
  index: number;
  label: string;
  value: number;
  fixed: boolean;
  isNonScoreCell: boolean; // Flag for Sum, Bonus, Total cells

  constructor(index: number, label: string, isNonScoreCell: boolean = false) {
    this.index = index;
    this.label = label;
    this.value = label.toLowerCase() === 'sum' ||  label.toLowerCase() === 'total' ? 0 : -1; // Default to -1 (empty)
    this.fixed = label.toLowerCase() === 'sum' || label.toLowerCase().includes('bonus') || label.toLowerCase() === 'total';
    this.isNonScoreCell = isNonScoreCell || label.toLowerCase() === 'sum' || label.toLowerCase().includes('bonus') || label.toLowerCase() === 'total';

  }

  // Method to serialize cell data
  toJSON(): any {
    return {
      index: this.index,
      label: this.label, // Include label for context if needed
      value: this.value,
      fixed: this.fixed,
      isNonScoreCell: this.isNonScoreCell
    };
  }

   // Static method to reconstruct from JSON
   static fromJson(data: any, defaultLabel?: string): BoardCell {
       const cell = new BoardCell(
           data.index,
           data.label ?? defaultLabel ?? `Cell ${data.index}`, // Use label from data, fallback to default or index
           data.isNonScoreCell ?? false
       );
       cell.value = data.value ?? -1;
       cell.fixed = data.fixed ?? false;
       return cell;
   }
}