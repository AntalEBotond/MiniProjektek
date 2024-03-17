public class Matrix {
    public static void main(String[] args) {
        int[][] matrix = new int[10][10];

        for (int i = 0; i < 10; i++) {
            matrix[i][i] = i + 1;
        }

        for (int i = 0; i < 10; i++) {
            for (int j = 0; j < 10; j++) {
                System.out.print(matrix[i][j] + " ");
            }
            System.out.println();
        }
    }
}
