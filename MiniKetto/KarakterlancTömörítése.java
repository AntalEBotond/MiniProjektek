import java.util.Scanner;

public class KarakterlancTömörítése {
    public static void main(String[] args) {
        Scanner scanner = new Scanner(System.in);

        System.out.println("Adj meg egy szót:");
        String szo = scanner.nextLine();

        StringBuilder sb = new StringBuilder();
        char prevChar = szo.charAt(0);
        int count = 1;
        for (int i = 1; i < szo.length(); i++) {
            char currentChar = szo.charAt(i);
            if (currentChar == prevChar) {
                count++;
            } else {
                sb.append(prevChar);
                sb.append(count);
                prevChar = currentChar;
                count = 1;
            }
        }
        sb.append(prevChar);
        sb.append(count);
        System.out.println("Tömörített szó: " + sb.toString());

        scanner.close();
    }
}
